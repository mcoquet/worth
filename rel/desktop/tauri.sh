#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
TAURI_DIR="$SCRIPT_DIR/src-tauri"
RELEASE_NAME="desktop"

# Detect OS for platform-specific release directory
case "$(uname -s)" in
  Linux*)  OS_NAME="linux" ;;
  Darwin*) OS_NAME="darwin" ;;
  MINGW*|MSYS*|CYGWIN*) OS_NAME="windows" ;;
  *) echo "Unsupported OS"; exit 1 ;;
esac

RELEASE_DIR="$TAURI_DIR/rel-${OS_NAME}"

mix_release() {
    echo "==> Building OTP release (${OS_NAME})..."
    cd "$PROJECT_DIR"

    MIX_ENV=prod mix deps.get --only prod
    MIX_ENV=prod mix assets.deploy
    MIX_ENV=prod mix release "$RELEASE_NAME" --overwrite \
        --path "$RELEASE_DIR"

    # Ensure all files are writable (some NIFs ship read-only .so files)
    find "$RELEASE_DIR" -type f ! -perm -u+w -exec chmod u+w {} +

    echo "==> OTP release built at $RELEASE_DIR"
}

tauri_build() {
    echo "==> Building Tauri application..."
    cd "$TAURI_DIR"

    if ! command -v cargo &>/dev/null; then
        echo "Error: cargo not found. Install Rust: https://rustup.rs"
        exit 1
    fi

    # Prepare splash screen dist
    mkdir -p dist
    cp dist_splash.html dist/index.html

    # Pass resources dynamically so tauri.conf.json stays clean
    cargo tauri build --config "{\"bundle\":{\"resources\":{\"rel-${OS_NAME}\":\"rel\"}}}"
    echo "==> Tauri build complete"
    echo "Artifacts at: $TAURI_DIR/target/release/bundle/"
}

dev() {
    echo "==> Starting in dev mode..."
    cd "$PROJECT_DIR"
    MIX_ENV=prod mix release "$RELEASE_NAME" --overwrite \
        --path "$TAURI_DIR/release" 2>/dev/null || true
    cd "$TAURI_DIR"
    cargo tauri dev
}

case "${1:-build}" in
    release)  mix_release ;;
    tauri)    tauri_build ;;
    build)    mix_release && tauri_build ;;
    dev)      dev ;;
    *)
        echo "Usage: $0 {release|tauri|build|dev}"
        echo ""
        echo "  release  - Build OTP release only"
        echo "  tauri    - Build Tauri app only (requires existing OTP release)"
        echo "  build    - Build both OTP release and Tauri app"
        echo "  dev      - Start Tauri in dev mode"
        exit 1
        ;;
esac
