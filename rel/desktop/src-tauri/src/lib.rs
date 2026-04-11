use base64::Engine;
use std::io::{Read, Write};
use std::net::TcpListener;
use std::process::{Child, Command, ExitStatus};
use std::sync::Mutex;
use tauri::{
    menu::{MenuBuilder, MenuItemBuilder},
    tray::TrayIconBuilder,
    Manager, RunEvent,
};
use tauri_plugin_dialog::DialogExt;

/// Maximum allowed frame payload size (1 MB) to prevent memory exhaustion
/// from malformed or malicious frames.
const MAX_FRAME_SIZE: usize = 1024 * 1024;

struct AppState {
    otp_process: Mutex<Option<Child>>,
    pubsub_port: Mutex<u16>,
    pubsub_stream: Mutex<Option<std::net::TcpStream>>,
}

pub fn run() {
    tauri::Builder::default()
        .plugin(tauri_plugin_single_instance::init(|app, _args, _cwd| {
            if let Some(window) = app.get_webview_window("main") {
                let _ = window.set_focus();
            }
        }))
        .plugin(tauri_plugin_dialog::init())
        .plugin(tauri_plugin_clipboard_manager::init())
        .manage(AppState {
            otp_process: Mutex::new(None),
            pubsub_port: Mutex::new(0),
            pubsub_stream: Mutex::new(None),
        })
        .setup(|app| {
            // Build tray menu
            let quit_item = MenuItemBuilder::with_id("quit", "Quit Worth").build(app)?;
            let open_item = MenuItemBuilder::with_id("open", "Open Worth").build(app)?;

            let menu = MenuBuilder::new(app)
                .items(&[&open_item, &quit_item])
                .build()?;

            // Build a single tray icon with both icon and menu
            let _tray = TrayIconBuilder::new()
                .icon(app.default_window_icon().cloned().unwrap_or_else(|| {
                    tauri::image::Image::new(&[], 0, 0)
                }))
                .menu(&menu)
                .show_menu_on_left_click(false)
                .on_menu_event(|app, event| match event.id().as_ref() {
                    "quit" => {
                        send_pubsub(app, "quit", "");
                        kill_otp(app);
                        app.exit(0);
                    }
                    "open" => {
                        if let Some(window) = app.get_webview_window("main") {
                            let _ = window.set_focus();
                            let _ = window.show();
                        }
                    }
                    _ => {}
                })
                .build(app)?;

            start_otp_and_create_window(app)?;

            Ok(())
        })
        .build(tauri::generate_context!())
        .expect("error while building tauri application")
        .run(|app, event| {
            if let RunEvent::ExitRequested { .. } = event {
                send_pubsub(app, "quit", "");
                kill_otp(app);
                app.exit(0);
            }
        });
}

fn send_pubsub(app: &tauri::AppHandle, topic: &str, payload: &str) {
    let state = app.state::<AppState>();
    let Ok(mut stream_guard) = state.pubsub_stream.lock() else {
        eprintln!("[worth] failed to acquire pubsub_stream lock (poisoned)");
        return;
    };
    if let Some(ref mut stream) = *stream_guard {
        let _ = write_frame(stream, topic, payload);
    }
}

fn kill_otp(app: &tauri::AppHandle) {
    let state = app.state::<AppState>();
    let Ok(mut proc) = state.otp_process.lock() else {
        eprintln!("[worth] failed to acquire otp_process lock (poisoned)");
        return;
    };
    if let Some(ref mut child) = *proc {
        // Attempt graceful shutdown first via pubsub, then force kill after timeout
        let _ = child.kill();
        let _ = child.wait();
    }
    *proc = None;
}

fn release_dir(app: &tauri::App) -> std::path::PathBuf {
    let resource_rel = app.path().resource_dir().map(|d| d.join("rel")).ok();

    if let Some(dir) = resource_rel {
        if dir.join("bin").exists() {
            return dir;
        }
    }

    let exe_dir = std::env::current_exe()
        .ok()
        .and_then(|p| p.parent().map(|d| d.to_path_buf()));

    if let Some(dir) = exe_dir {
        let dev_rel = dir.join("../../release");
        if dev_rel.join("bin").exists() {
            return dev_rel;
        }
    }

    app.path()
        .resource_dir()
        .expect("failed to determine resource directory")
        .join("rel")
}

fn start_otp_and_create_window(app: &mut tauri::App) -> Result<(), Box<dyn std::error::Error>> {
    let release_dir = release_dir(app);
    eprintln!("[worth] release_dir = {:?}", release_dir);

    let otp_bin = if cfg!(target_os = "windows") {
        release_dir.join("bin").join("desktop.bat")
    } else {
        release_dir.join("bin").join("desktop")
    };

    if !otp_bin.exists() {
        return Err(format!("OTP binary not found: {:?}", otp_bin).into());
    }

    let http_port = find_available_port()?;
    eprintln!("[worth] http_port = {}", http_port);

    let listener = TcpListener::bind("127.0.0.1:0")
        .map_err(|e| format!("Failed to bind TCP listener: {}", e))?;
    let pubsub_port = listener.local_addr()?.port();
    listener.set_nonblocking(true)?;

    {
        let state = app.state::<AppState>();
        let Ok(mut guard) = state.pubsub_port.lock() else {
            return Err("pubsub_port mutex poisoned".into());
        };
        *guard = pubsub_port;
    }

    let mut cmd = Command::new(&otp_bin);
    cmd.arg("start")
        .env("WORTH_DESKTOP", "1")
        .env("PHX_SERVER", "true")
        .env("PORT", http_port.to_string())
        .env("WORTH_DATABASE_BACKEND", "libsql")
        .env("WORTH_AUTO_MIGRATE", "1")
        .env("SECRET_KEY_BASE", generate_secret_key_base())
        .env("WORTH_PUBSUB", format!("tcp://127.0.0.1:{}", pubsub_port));

    #[cfg(target_os = "windows")]
    {
        use std::os::windows::process::CommandExt;
        cmd.creation_flags(0x00000008); // CREATE_NO_WINDOW
    }

    let child = cmd.spawn()?;
    {
        let state = app.state::<AppState>();
        let Ok(mut guard) = state.otp_process.lock() else {
            return Err("otp_process mutex poisoned".into());
        };
        *guard = Some(child);
    }

    // Create splash screen with loading indicator
    let splash_window = tauri::WebviewWindowBuilder::new(
        app,
        "splash",
        tauri::WebviewUrl::App("index.html".into()),
    )
    .title("Worth")
    .inner_size(480.0, 320.0)
    .resizable(false)
    .decorations(false)
    .center()
    .build()?;

    let app_handle = app.handle().clone();
    let splash_label = splash_window.label().to_string();

    std::thread::spawn(move || {
        let (stream, url) = wait_for_ready(&listener, 60);

        if stream.is_none() {
            show_crash_dialog(
                &app_handle,
                "Worth failed to start",
                &format!(
                    "The backend did not signal ready within 60 seconds.\n\nLogs may be available at:\n{}/worth.log",
                    worth_home_dir()
                ),
            );
            let _ = app_handle
                .get_webview_window(&splash_label)
                .map(|w| w.close());
            app_handle.exit(1);
            return;
        }

        // Safe: we just checked is_none() above
        let stream = stream.unwrap();

        {
            let state = app_handle.state::<AppState>();
            let Ok(mut guard) = state.pubsub_stream.lock() else {
                eprintln!("[worth] pubsub_stream mutex poisoned, cannot store stream");
                app_handle.exit(1);
                return;
            };
            match stream.try_clone() {
                Ok(cloned) => *guard = Some(cloned),
                Err(e) => {
                    eprintln!("[worth] failed to clone pubsub stream: {}", e);
                    app_handle.exit(1);
                    return;
                }
            }
        }

        // Close splash screen
        let _ = app_handle
            .get_webview_window(&splash_label)
            .map(|w| w.close());

        // Parse the URL safely
        let parsed_url = match url.parse() {
            Ok(u) => u,
            Err(e) => {
                eprintln!("[worth] failed to parse URL '{}': {}", url, e);
                show_crash_dialog(
                    &app_handle,
                    "Worth failed to start",
                    &format!("Invalid URL received from backend: {}", url),
                );
                app_handle.exit(1);
                return;
            }
        };

        let main_window = match tauri::WebviewWindowBuilder::new(
            &app_handle,
            "main",
            tauri::WebviewUrl::External(parsed_url),
        )
        .title("Worth")
        .inner_size(1280.0, 900.0)
        .center()
        .build()
        {
            Ok(w) => w,
            Err(e) => {
                eprintln!("[worth] failed to create main window: {}", e);
                show_crash_dialog(&app_handle, "Worth failed to start", &format!("Could not create main window: {}", e));
                app_handle.exit(1);
                return;
            }
        };

        let win = main_window.clone();
        main_window.on_window_event(move |event| {
            if let tauri::WindowEvent::CloseRequested { api, .. } = event {
                api.prevent_close();
                let _ = win.hide();
            }
        });

        let _ = main_window.set_focus();

        listen_pubsub(&app_handle, stream);
        monitor_otp_process(&app_handle);
    });

    Ok(())
}

fn wait_for_ready(
    listener: &TcpListener,
    timeout_secs: u64,
) -> (Option<std::net::TcpStream>, String) {
    let deadline = std::time::Instant::now() + std::time::Duration::from_secs(timeout_secs);
    let mut buf = [0u8; 4096];

    loop {
        if std::time::Instant::now() > deadline {
            eprintln!("[worth] timed out waiting for backend ready signal");
            return (None, String::new());
        }

        match listener.accept() {
            Ok((mut stream, _addr)) => {
                stream
                    .set_read_timeout(Some(std::time::Duration::from_secs(timeout_secs)))
                    .ok();

                loop {
                    match stream.read(&mut buf) {
                        Ok(0) => return (None, String::new()),
                        Ok(n) => {
                            if let Some((topic, payload)) = parse_frame(&buf[..n]) {
                                if topic == "worth" && payload.starts_with("ready:") {
                                    let url = payload.strip_prefix("ready:").unwrap().to_string();
                                    eprintln!("[worth] backend ready at {}", url);
                                    return (Some(stream), url);
                                }
                            }
                        }
                        Err(ref e) if e.kind() == std::io::ErrorKind::WouldBlock => {
                            std::thread::sleep(std::time::Duration::from_millis(100));
                            continue;
                        }
                        Err(e) => {
                            eprintln!("[worth] read error while waiting for ready: {}", e);
                            return (None, String::new());
                        }
                    }
                }
            }
            Err(ref e) if e.kind() == std::io::ErrorKind::WouldBlock => {
                std::thread::sleep(std::time::Duration::from_millis(100));
                continue;
            }
            Err(_) => {
                std::thread::sleep(std::time::Duration::from_millis(100));
                continue;
            }
        }
    }
}

fn listen_pubsub(app: &tauri::AppHandle, mut stream: std::net::TcpStream) {
    let mut buf = [0u8; 4096];
    stream
        .set_read_timeout(Some(std::time::Duration::from_secs(5)))
        .ok();

    loop {
        match stream.read(&mut buf) {
            Ok(0) => {
                eprintln!("[worth] PubSub connection closed by Elixir side");
                return;
            }
            Ok(n) => {
                if let Some((topic, payload)) = parse_frame(&buf[..n]) {
                    if topic == "worth" && payload == "shutdown" {
                        eprintln!("[worth] received shutdown from Elixir");
                        kill_otp(app);
                        app.exit(0);
                        return;
                    }
                }
            }
            Err(ref e) if e.kind() == std::io::ErrorKind::WouldBlock => continue,
            Err(ref e) if e.kind() == std::io::ErrorKind::TimedOut => continue,
            Err(e) => {
                eprintln!("[worth] PubSub read error: {}", e);
                return;
            }
        }
    }
}

fn parse_frame(data: &[u8]) -> Option<(String, String)> {
    if data.len() < 6 {
        return None;
    }

    let length = u32::from_be_bytes([data[0], data[1], data[2], data[3]]) as usize;

    // Reject frames larger than MAX_FRAME_SIZE to prevent memory exhaustion
    if length > MAX_FRAME_SIZE {
        eprintln!("[worth] rejecting oversized frame: {} bytes (max {})", length, MAX_FRAME_SIZE);
        return None;
    }

    if data.len() < 4 + length {
        return None;
    }

    let frame = &data[4..4 + length];
    if frame.is_empty() || frame[0] != 1 {
        return None;
    }

    let topic_len = frame[1] as usize;
    if frame.len() < 2 + topic_len {
        return None;
    }

    let topic = String::from_utf8_lossy(&frame[2..2 + topic_len]).to_string();
    let payload = String::from_utf8_lossy(&frame[2 + topic_len..]).to_string();

    Some((topic, payload))
}

fn write_frame(
    stream: &mut std::net::TcpStream,
    topic: &str,
    payload: &str,
) -> std::io::Result<()> {
    let topic_bytes = topic.as_bytes();
    let payload_bytes = payload.as_bytes();
    let frame_len = 1 + 1 + topic_bytes.len() + payload_bytes.len();

    let mut frame = Vec::with_capacity(4 + frame_len);
    frame.extend_from_slice(&(frame_len as u32).to_be_bytes());
    frame.push(1); // protocol version
    frame.push(topic_bytes.len() as u8);
    frame.extend_from_slice(topic_bytes);
    frame.extend_from_slice(payload_bytes);

    stream.write_all(&frame)
}

fn monitor_otp_process(app: &tauri::AppHandle) {
    let state = app.state::<AppState>();
    loop {
        std::thread::sleep(std::time::Duration::from_secs(1));
        let Ok(mut guard) = state.otp_process.lock() else {
            eprintln!("[worth] otp_process mutex poisoned in monitor");
            return;
        };
        match guard.as_mut() {
            Some(child) => match child.try_wait() {
                Ok(Some(status)) => {
                    let msg = format_crash_message(status);
                    *guard = None;
                    drop(guard);
                    show_crash_dialog(app, "Worth crashed", &msg);
                    app.exit(1);
                    return;
                }
                Ok(None) => {}
                Err(e) => {
                    eprintln!("[worth] failed to check OTP process: {}", e);
                }
            },
            None => return,
        };
    }
}

fn format_crash_message(status: ExitStatus) -> String {
    format!(
        "The Worth backend process exited unexpectedly ({}).\n\nLogs may be available at:\n{}/worth.log",
        status,
        worth_home_dir()
    )
}

fn show_crash_dialog(app: &tauri::AppHandle, title: &str, message: &str) {
    let dialog = app.dialog();
    let _ = dialog.message(message).title(title).blocking_show();
}

fn worth_home_dir() -> String {
    std::env::var("WORTH_HOME")
        .ok()
        .or_else(|| std::env::var("HOME").ok().map(|h| format!("{}/.worth", h)))
        .unwrap_or_else(|| "~/.worth".to_string())
}

fn find_available_port() -> Result<u16, Box<dyn std::error::Error>> {
    let listener = TcpListener::bind("127.0.0.1:0")
        .map_err(|e| format!("failed to bind to random port: {}", e))?;
    let port = listener
        .local_addr()
        .map_err(|e| format!("failed to get local address: {}", e))?
        .port();
    Ok(port)
}

fn generate_secret_key_base() -> String {
    let mut bytes = [0u8; 48];
    getrandom::getrandom(&mut bytes).expect("failed to generate random bytes");
    base64::engine::general_purpose::STANDARD.encode(bytes)
}
