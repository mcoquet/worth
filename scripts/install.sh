#!/usr/bin/env bash
#
# Worth Desktop — Linux installer
#
# Usage:
#   curl -sSL https://raw.githubusercontent.com/kittyfromouterspace/worth/main/scripts/install.sh | bash
#
# Or with a specific version:
#   curl -sSL ... | bash -s -- v0.1.0
#
set -euo pipefail

REPO="kittyfromouterspace/worth"
INSTALL_DIR="${WORTH_INSTALL_DIR:-$HOME/.local/bin}"
APP_NAME="worth"

# Colors (if terminal supports them)
if [ -t 1 ]; then
  BOLD="\033[1m"
  BLUE="\033[34m"
  GREEN="\033[32m"
  RED="\033[31m"
  RESET="\033[0m"
else
  BOLD="" BLUE="" GREEN="" RED="" RESET=""
fi

info()  { echo -e "${BLUE}${BOLD}info${RESET}  $*"; }
ok()    { echo -e "${GREEN}${BOLD}ok${RESET}    $*"; }
error() { echo -e "${RED}${BOLD}error${RESET} $*" >&2; }

# Detect platform
detect_platform() {
  local os arch
  os="$(uname -s)"
  arch="$(uname -m)"

  case "$os" in
    Linux)  ;;
    Darwin)
      error "macOS detected. Please download the .dmg from:"
      error "  https://github.com/$REPO/releases/latest"
      exit 1
      ;;
    *)
      error "Unsupported OS: $os"
      exit 1
      ;;
  esac

  case "$arch" in
    x86_64|amd64) ;;
    aarch64|arm64)
      error "ARM64 Linux builds are not yet available."
      error "Please build from source: https://github.com/$REPO"
      exit 1
      ;;
    *)
      error "Unsupported architecture: $arch"
      exit 1
      ;;
  esac
}

# Get latest version tag from GitHub
get_version() {
  local version="${1:-}"
  if [ -n "$version" ]; then
    echo "$version"
    return
  fi

  info "Fetching latest version..."
  version=$(curl -sSf "https://api.github.com/repos/$REPO/releases/latest" \
    | grep '"tag_name"' \
    | head -1 \
    | cut -d'"' -f4)

  if [ -z "$version" ]; then
    error "Could not determine latest version."
    error "Please specify a version: $0 v0.1.0"
    exit 1
  fi

  echo "$version"
}

# Download and install
install() {
  local version="$1"
  local download_url="https://github.com/$REPO/releases/download/$version"

  # Try AppImage first
  local appimage_name="${APP_NAME}_${version#v}_amd64.AppImage"
  local appimage_url="$download_url/$appimage_name"

  info "Downloading Worth $version..."

  local tmp_dir
  tmp_dir="$(mktemp -d)"
  trap 'rm -rf "$tmp_dir"' EXIT

  local http_code
  http_code=$(curl -sSL -w "%{http_code}" -o "$tmp_dir/$appimage_name" "$appimage_url" 2>/dev/null || echo "000")

  if [ "$http_code" != "200" ]; then
    # Try alternate naming conventions
    for name in \
      "Worth_${version#v}_amd64.AppImage" \
      "worth-linux-x86_64.AppImage" \
      "Worth-linux-x86_64.AppImage"; do
      http_code=$(curl -sSL -w "%{http_code}" -o "$tmp_dir/$name" "$download_url/$name" 2>/dev/null || echo "000")
      if [ "$http_code" = "200" ]; then
        appimage_name="$name"
        break
      fi
    done

    if [ "$http_code" != "200" ]; then
      error "Could not download Worth $version."
      error "Check available releases at: https://github.com/$REPO/releases"
      exit 1
    fi
  fi

  # Install
  mkdir -p "$INSTALL_DIR"
  mv "$tmp_dir/$appimage_name" "$INSTALL_DIR/$APP_NAME"
  chmod +x "$INSTALL_DIR/$APP_NAME"

  ok "Worth $version installed to $INSTALL_DIR/$APP_NAME"

  # Check if INSTALL_DIR is in PATH
  case ":$PATH:" in
    *":$INSTALL_DIR:"*) ;;
    *)
      echo ""
      info "Add $INSTALL_DIR to your PATH:"
      echo "  export PATH=\"$INSTALL_DIR:\$PATH\""
      echo ""
      info "Or add it to your shell profile (~/.bashrc, ~/.zshrc, etc.)"
      ;;
  esac
}

main() {
  detect_platform
  local version
  version=$(get_version "${1:-}")
  install "$version"

  echo ""
  ok "Run 'worth' to start the app."
}

main "$@"
