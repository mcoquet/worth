#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
TAURI_DIR="$SCRIPT_DIR/src-tauri"
RELEASE_NAME="desktop"

mix_release() {
    echo "==> Building OTP release..."
    cd "$PROJECT_DIR"

    MIX_ENV=prod mix deps.get --only prod
    MIX_ENV=prod mix assets.deploy
    MIX_ENV=prod mix release "$RELEASE_NAME" --overwrite \
        --path "$TAURI_DIR/release"

    echo "==> OTP release built at $TAURI_DIR/release"
}

tauri_build() {
    echo "==> Preparing OTP release for bundling..."
    mkdir -p "$TAURI_DIR/src-tauri/rel"
    cp -a "$TAURI_DIR/release/"* "$TAURI_DIR/rel/"

    echo "==> Building Tauri application..."
    cd "$TAURI_DIR"

    if ! command -v cargo &>/dev/null; then
        echo "Error: cargo not found. Install Rust: https://rustup.rs"
        exit 1
    fi

    cargo tauri build
    echo "==> Tauri build complete"
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
