use base64::Engine;
use std::process::{Child, Command, ExitStatus};
use std::sync::Mutex;
use tauri::{
    menu::{MenuBuilder, MenuItemBuilder},
    tray::TrayIconBuilder,
    Manager, RunEvent,
};
use tauri_plugin_dialog::DialogExt;

struct AppState {
    otp_process: Mutex<Option<Child>>,
    port: Mutex<u16>,
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
            port: Mutex::new(0),
        })
        .setup(|app| {
            let quit_item = MenuItemBuilder::with_id("quit", "Quit Worth").build(app)?;
            let open_item = MenuItemBuilder::with_id("open", "Open Worth").build(app)?;

            let menu = MenuBuilder::new(app)
                .items(&[&open_item, &quit_item])
                .build()?;

            let _tray = TrayIconBuilder::new()
                .menu(&menu)
                .show_menu_on_left_click(false)
                .on_menu_event(|app, event| match event.id().as_ref() {
                    "quit" => {
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
                kill_otp(app);
                app.exit(0);
            }
        });
}

fn kill_otp(app: &tauri::AppHandle) {
    let state = app.state::<AppState>();
    let mut proc = state.otp_process.lock().unwrap();
    if let Some(ref mut child) = *proc {
        let _ = child.kill();
        let _ = child.wait();
    }
    *proc = None;
}

fn start_otp_and_create_window(app: &mut tauri::App) -> Result<(), Box<dyn std::error::Error>> {
    let release_dir = app.path().resource_dir()?.join("rel");

    let otp_bin = if cfg!(target_os = "windows") {
        release_dir.join("bin").join("desktop.bat")
    } else {
        release_dir.join("bin").join("desktop")
    };

    let port = find_available_port();
    *app.state::<AppState>().port.lock().unwrap() = port;

    let mut cmd = Command::new(&otp_bin);
    cmd.arg("start")
        .env("WORTH_DESKTOP", "1")
        .env("PHX_SERVER", "true")
        .env("PORT", port.to_string())
        .env("WORTH_DATABASE_BACKEND", "libsql")
        .env("WORTH_AUTO_MIGRATE", "1")
        .env("SECRET_KEY_BASE", generate_secret_key_base());

    #[cfg(target_os = "windows")]
    {
        use std::os::windows::process::CommandExt;
        cmd.creation_flags(0x00000008);
    }

    let child = cmd.spawn()?;
    let state = app.state::<AppState>();
    *state.otp_process.lock().unwrap() = Some(child);

    let url = format!("http://127.0.0.1:{}", port);

    let splash_window = tauri::WebviewWindowBuilder::new(
        app,
        "splash",
        tauri::WebviewUrl::App("splash.html".into()),
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
        let started = wait_for_server(&url, 45);

        if !started {
            show_crash_dialog(
                &app_handle,
                "Worth failed to start",
                &format!(
                    "The server did not respond within 45 seconds.\n\nLogs may be available at:\n{}/worth.log",
                    worth_home_dir()
                ),
            );
            let _ = app_handle
                .get_webview_window(&splash_label)
                .map(|w| w.close());
            app_handle.exit(1);
            return;
        }

        let _ = app_handle
            .get_webview_window(&splash_label)
            .map(|w| w.close());

        let main_window = tauri::WebviewWindowBuilder::new(
            &app_handle,
            "main",
            tauri::WebviewUrl::External(url.parse().unwrap()),
        )
        .title("Worth")
        .inner_size(1280.0, 900.0)
        .center()
        .build()
        .expect("failed to create main window");
        let _ = main_window.set_focus();

        monitor_otp_process(&app_handle);
    });

    Ok(())
}

fn monitor_otp_process(app: &tauri::AppHandle) {
    let state = app.state::<AppState>();
    loop {
        std::thread::sleep(std::time::Duration::from_secs(5));
        let mut guard = state.otp_process.lock().unwrap();
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
                    eprintln!("Failed to check OTP process: {}", e);
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

fn find_available_port() -> u16 {
    use std::net::TcpListener;
    let listener = TcpListener::bind("127.0.0.1:0").expect("failed to bind to random port");
    listener.local_addr().unwrap().port()
}

fn wait_for_server(url: &str, max_retries: u32) -> bool {
    let client = reqwest::blocking::Client::builder()
        .timeout(std::time::Duration::from_secs(2))
        .build()
        .unwrap_or_default();

    for _ in 0..max_retries {
        if client.get(url).send().is_ok() {
            return true;
        }
        std::thread::sleep(std::time::Duration::from_secs(1));
    }
    false
}

fn generate_secret_key_base() -> String {
    let mut bytes = [0u8; 48];
    getrandom::getrandom(&mut bytes).expect("failed to generate random bytes");
    base64::engine::general_purpose::STANDARD.encode(bytes)
}
