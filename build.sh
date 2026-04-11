#!/bin/sh

export MIX_ENV=prod
mix release desktop --overwrite --path rel/desktop/src-tauri/release
cd rel/desktop/src-tauri
cargo build --release
./target/release/worth-desktop
cd -
