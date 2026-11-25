#!/usr/bin/env bash
# Installs the latest Upright release into /Applications and opens it.
#
#   curl -fsSL https://raw.githubusercontent.com/oliveirarodrigo2097/upright/main/scripts/install.sh | bash
#
# Options (environment variables):
#   UPRIGHT_ZIP=path    install from a local Upright.zip instead of downloading
#   UPRIGHT_DEST=dir    install somewhere other than /Applications
#   UPRIGHT_NO_OPEN=1   don't open the app afterwards
set -euo pipefail

REPO="oliveirarodrigo2097/upright"
URL="https://github.com/$REPO/releases/latest/download/Upright.zip"

say() { printf '\033[1m==>\033[0m %s\n' "$*"; }
fail() { printf '\033[31mError:\033[0m %s\n' "$*" >&2; exit 1; }

[[ "$(uname -s)" == "Darwin" ]] || fail "Upright is a macOS app."
major="$(sw_vers -productVersion | cut -d. -f1)"
(( major >= 14 )) || fail "Upright needs macOS 14 (Sonoma) or later; this Mac has $(sw_vers -productVersion)."

dest="${UPRIGHT_DEST:-/Applications}"
if [[ -z "${UPRIGHT_DEST:-}" && ! -w "$dest" ]]; then
    dest="$HOME/Applications"
fi
mkdir -p "$dest"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

if [[ -n "${UPRIGHT_ZIP:-}" ]]; then
    say "Using $UPRIGHT_ZIP"
    cp "$UPRIGHT_ZIP" "$tmp/Upright.zip"
else
    say "Downloading the latest Upright release"
    curl -fsSL "$URL" -o "$tmp/Upright.zip" \
        || fail "Couldn't download $URL. Check your connection, or build from source (see the README)."
fi

ditto -x -k "$tmp/Upright.zip" "$tmp/unzipped"
[[ -d "$tmp/unzipped/Upright.app" ]] || fail "The download didn't contain Upright.app."

if pgrep -xq Upright; then
    say "Quitting the running copy of Upright"
    pkill -x Upright || true
    sleep 1
fi

say "Installing to $dest/Upright.app"
rm -rf "$dest/Upright.app"
ditto "$tmp/unzipped/Upright.app" "$dest/Upright.app"

if [[ "${UPRIGHT_NO_OPEN:-0}" != "1" ]]; then
    open "$dest/Upright.app"
    say "Upright is running. Look for the figure icon in your menu bar."
else
    say "Installed."
fi
