# Security Proposal: Filesystem Sandboxing for Tauri App & Coding Agents

**Status:** Draft  
**Date:** 2026-04-14  
**Goal:** Restrict the Tauri application and all spawned coding-agent subprocesses to only two filesystem locations: (1) the user-defined workspace directory, and (2) the application’s private cache/config directory containing databases.

---

## 1. Executive Summary

This proposal outlines a defense-in-depth strategy for filesystem isolation across three layers:

1. **Tauri IPC Scope** – restricts what the frontend can request via the `fs` plugin.
2. **OS-Level App Sandboxing** – hardens the main application process using native platform primitives (macOS App Sandbox, Linux namespaces/Landlock, Windows restricted tokens).
3. **Agent Subprocess Sandboxing** – isolates spawned coding agents so they cannot escape the workspace or app-data boundaries even if compromised.

**Key finding:** There is no single cross-platform silver bullet. macOS provides the strongest native sandbox (App Sandbox + Security-Scoped Bookmarks). Linux offers excellent flexibility via `bubblewrap` + `seccomp`. Windows is the weakest link—true isolation requires complex AppContainer integration or falling back to ACL-based restrictions.

---

## 2. Threat Model

| Threat | Mitigation Layer |
|--------|------------------|
| Compromised frontend attempts to read/write arbitrary files | Layer 1 (Tauri capabilities) |
| Compromised Rust backend bypasses IPC and uses `std::fs` directly | Layer 2 (OS sandbox) |
| Malicious coding agent reads `~/.ssh`, modifies system files, or exfiltrates data outside the workspace | Layer 3 (Agent sandbox) |
| Agent performs a fork bomb, memory exhaustion, or syscall abuse | Layer 3 (Namespaces + rlimits + seccomp) |

---

## 3. Layer 1: Tauri IPC Scope (Frontend → Backend)

Tauri v2 uses a capability-based permission model. By default **all** filesystem access is denied. We configure explicit scopes in `src-tauri/capabilities/main.json`.

### 3.1 Static Capabilities

Restrict the frontend to only the app’s private directories and the user-defined workspace:

```json
{
  "$schema": "../gen/schemas/desktop-schema.json",
  "identifier": "main-capability",
  "windows": ["main"],
  "permissions": [
    {
      "identifier": "fs:scope",
      "allow": [
        { "path": "$APPDATA/**" },
        { "path": "$APPCONFIG/**" }
      ]
    },
    {
      "identifier": "fs:allow-read",
      "allow": [{ "path": "/user/defined/workspace/**" }]
    },
    {
      "identifier": "fs:allow-write",
      "allow": [{ "path": "/user/defined/workspace/**" }]
    }
  ]
}
```

**Limitation:** This only restricts the **frontend**. A compromised Rust backend can bypass these scopes entirely by using `std::fs` directly. Therefore, Layer 2 is required for real hardening.

### 3.2 Dynamic Scope Expansion

Since the workspace directory is chosen at runtime (e.g., via a file picker), we expand the scope dynamically from Rust using the `FsExt` trait:

```rust
use tauri_plugin_fs::FsExt;

#[tauri::command]
fn set_workspace(app: tauri::AppHandle, path: std::path::PathBuf) -> Result<(), String> {
    app.fs_scope()
      .allow_directory(&path, true) // true = recursive
      .map_err(|e| e.to_string())
}
```

---

## 4. Layer 2: OS-Level App Sandboxing

Native sandboxing is **platform-specific** and varies significantly in strength.

### 4.1 macOS: App Sandbox (Seatbelt)

macOS provides the strongest native desktop sandbox.

- **Entitlements:** Create an `Entitlements.plist` and reference it in `tauri.conf.json`. The kernel enforces restrictions once the app is **code-signed**.
  ```xml
  <key>com.apple.security.app-sandbox</key><true/>
  <key>com.apple.security.files.user-selected.read-write</key><true/>
  <key>com.apple.security.files.bookmarks.app-scope</key><true/>
  ```
- **Container isolation:** By default the app can only read/write its own container (`~/Library/Containers/<bundle-id>`).
- **Persistent workspace access:** Use **Security-Scoped Bookmarks** to save user-granted directory access across app restarts. Tauri v2 exposes:
  - `startAccessingSecurityScopedResource(path)`
  - `stopAccessingSecurityScopedResource(path)`
- **Development caveat:** `tauri dev` does **not** apply sandbox entitlements. Sandboxed behavior is only observable in signed release builds.

### 4.2 Linux: Flatpak, Landlock, or Bubblewrap

| Approach | Mechanism | Best For |
|----------|-----------|----------|
| **Flatpak** | `bubblewrap` namespaces + manifest permissions | Distribution packaging |
| **Landlock** | Unprivileged kernel LSM (5.13+) | In-app self-sandboxing |
| **Bubblewrap** | Direct namespace manipulation | Custom agent wrapping |

**Flatpak manifest example:**
```yaml
finish-args:
  - --filesystem=xdg-data/myapp
  - --filesystem=/home/user/workspace:rw
```

**Landlock critical gotcha:** Landlock restrictions apply to the **calling thread and all future children** and are **irreversible**. A known bug in ZeroClaw demonstrated that applying Landlock in the parent process before spawning a shell agent will **poison the parent**, breaking its own database access. Landlock must be applied *inside the child process* after spawning.

### 4.3 Windows: The Weakest Link

Windows lacks an easy namespace isolation primitive for traditional Win32 apps.

- **AppContainer:** The native sandbox (used by UWP). Launching a Win32 process inside an AppContainer is **complex, poorly documented, and brittle** (e.g., tray icons break, `OpenProcess` fails). Requires manual SID creation, ACL building, and `CreateProcessW` with `EXTENDED_STARTUPINFO_PRESENT`.
- **Practical alternative:** Use **NTFS ACLs + Restricted Tokens + Job Objects**. Spawn the agent under a low-privilege restricted token and lock down directory ACLs. This is permissions-based isolation, not true namespace isolation.
- **WSL2 fallback:** Some tools (e.g., OpenAI Codex) run their Linux sandbox (`bubblewrap`) inside WSL2 on Windows.

---

## 5. Layer 3: Sandboxing Spawning Coding Agents

**Tauri provides zero built-in sandboxing for child processes.** Sidecars and shell commands run with the **same privileges as the main app**. We must implement agent sandboxing ourselves.

### 5.1 Recommended Architecture: Broker Pattern

1. Keep the Tauri backend as an **unrestricted broker**.
2. Spawn coding agents as **child processes**.
3. Apply sandbox restrictions **inside the child** (or via a wrapper) — never in the parent.

### 5.2 Linux Agent Sandbox

**Bubblewrap (`bwrap`)** is the industry standard. Launch the agent inside a namespace with only the required mounts:

```bash
bwrap \
  --ro-bind /usr /usr \
  --ro-bind /etc /etc \
  --dev /dev \
  --proc /proc \
  --tmpfs /tmp \
  --bind "$WORKSPACE_DIR" /workspace \
  --bind "$APP_DATA_DIR" /appdata \
  --dir /run \
  --unshare-all \
  --die-with-parent \
  -- \
  /path/to/actual-agent "$@"
```

**Agent view:**
- `/workspace` → read-write
- `/appdata` → read-write
- `/usr`, `/etc` → read-only
- Fresh `/tmp`, `/dev`, `/proc`

**Hardening additions:**
- **seccomp BPF:** Block `ptrace`, `mount`, `pivot_root`, `chroot`, and unnecessary network syscalls.
- **Landlock:** Apply *inside* the bwrap child for defense-in-depth.
- **rlimits:** Cap memory (`RLIMIT_AS`), CPU (`RLIMIT_CPU`), file size (`RLIMIT_FSIZE`), and process count (`RLIMIT_NPROC`).

### 5.3 macOS Agent Sandbox

If the main Tauri app is signed with App Sandbox entitlements, child processes **inherit the sandbox automatically**. This means sidecars and shell agents are naturally constrained to the same container and Security-Scoped Bookmarked directories.

**Alternative (unsigned or stricter control):** Use `sandbox-exec` with a custom SBPL profile:
```bash
sandbox-exec -f /path/to/agent.sb /path/to/agent
```
**Warning:** `sandbox-exec` is **deprecated by Apple** with no public replacement.

### 5.4 Windows Agent Sandbox

| Option | Feasibility | Notes |
|--------|-------------|-------|
| **AppContainer** | Hard | True sandbox but requires significant native Win32 code; many APIs break inside it. |
| **Restricted Token + ACLs** | Moderate | Practical fallback. Deny the agent token access to all directories except workspace and app data. |
| **Job Objects** | Easy | Prevent UI injection, process creation limits, and breakaway. |
| **WSL2 + bwrap** | Easy (if WSL2 installed) | Run the agent inside WSL2 where Linux sandboxing tools work natively. |

---

## 6. Cross-Platform Summary

| Platform | App Sandbox | Agent Sandbox | Recommended Approach |
|----------|-------------|---------------|----------------------|
| **macOS** | Strong | Strong (inherits sandbox) | Sign app with App Sandbox + Security-Scoped Bookmarks. Spawn agents as sidecars. |
| **Linux** | Moderate | Strong (bwrap + seccomp) | Flatpak for distribution. Custom `bwrap` wrapper for agents with seccomp/rlimits. |
| **Windows** | Weak | Weak | Restricted tokens + NTFS ACLs + Job Objects. Evaluate WSL2 fallback for power users. |

---

## 7. Implementation Roadmap

### Phase 1 – Tauri IPC Hardening
- [ ] Remove all wildcard `fs:*` permissions from capabilities.
- [ ] Define static scopes for `$APPDATA`, `$APPCONFIG`.
- [ ] Implement runtime workspace scope expansion via `FsExt::allow_directory`.
- [ ] Add path traversal validation (reject `..` segments in workspace paths).

### Phase 2 – macOS Sandboxing
- [ ] Create `Entitlements.plist` with `com.apple.security.app-sandbox` and bookmark entitlements.
- [ ] Integrate `startAccessingSecurityScopedResource` / `stopAccessingSecurityScopedResource` for workspace persistence.
- [ ] Verify sidecar/agent inheritance in a signed release build.

### Phase 3 – Linux Agent Sandbox
- [ ] Build a Rust `AgentLauncher` module that constructs `bwrap` command lines.
- [ ] Bind-mount only workspace + app data + read-only system dirs.
- [ ] Integrate `seccompiler` to generate and load a minimal seccomp BPF filter.
- [ ] Set `RLIMIT_AS`, `RLIMIT_CPU`, `RLIMIT_NPROC`, `RLIMIT_FSIZE` before `execve`.

### Phase 4 – Windows Agent Sandbox
- [ ] Prototype a restricted-token launcher using the Windows API (`CreateRestrictedToken`, `CreateProcessAsUser`).
- [ ] Pre-seed NTFS ACLs on the workspace/app-data directories.
- [ ] Wrap agents in a Job Object to limit process creation.
- [ ] Spike a WSL2-based agent runner as an optional advanced mode.

### Phase 5 – Validation
- [ ] Penetration tests: attempt to read `~/.ssh`, write outside workspace, escape via symlinks, traverse parent directories.
- [ ] Resource exhaustion tests: fork bombs, memory bombs, disk-fill attempts.

---

## 8. Risks & Open Questions

| Risk | Impact | Mitigation |
|------|--------|------------|
| **macOS dev/testing gap** | High | Sandboxing only active in signed release builds. Consider a local ad-hoc signing script for `tauri dev` or test frequently in release mode. |
| **Landlock parent poisoning** | High | Never apply Landlock/seccomp in the main Tauri process. Always sandbox **after fork/spawn**, inside the agent. |
| **Windows complexity** | High | AppContainer may be infeasible for CLI agents. Start with restricted tokens + ACLs and iterate. |
| **Symlink escapes** | Medium | Resolve all symlinks in workspace paths before mounting into the sandbox. Use `O_NOFOLLOW` where possible. |
| **Agent needs system tools** | Medium | `bwrap` should include `--ro-bind /usr /usr` and `--ro-bind /bin /bin` so agents can run standard shells/compilers. |
| **Network isolation** | Medium | This proposal focuses on filesystem isolation. A follow-up should address network sandboxing (e.g., `bwrap --unshare-net`, WFP filters on Windows). |

---

## 9. References

- Tauri v2 File System Plugin & Scopes: https://v2.tauri.app/plugin/file-system/
- Tauri Dynamic Scope (`FsExt`): https://v2.tauri.app/security/scope/
- macOS App Sandbox Entitlements: https://v2.tauri.app/distribute/macos-application-bundle/
- Security-Scoped Bookmarks (Apple): https://developer.apple.com/documentation/professional-video-applications/enabling-security-scoped-bookmark-and-url-access
- Bubblewrap Manual: https://manpages.debian.org/bookworm/bubblewrap/bwrap.1.en.html
- Landlock Kernel Docs: https://landlock.io/
- Windows AppContainer Overview: https://learn.microsoft.com/en-us/windows/win32/secauthz/implementing-an-appcontainer
- Anthropic Sandbox Runtime (seccomp + bwrap patterns): https://www.npmjs.com/package/@anthropic-ai/sandbox-runtime
