#!/bin/sh
# TrackNum one-line installer
# curl -fsSL https://raw.githubusercontent.com/MoGuthmi/TrackNum/main/install.sh | sh
set -e

REPO="https://raw.githubusercontent.com/MoGuthmi/TrackNum/main"
DIR="$HOME/Applications/TrackNum"

if ! command -v swiftc >/dev/null 2>&1; then
  echo "→ Xcode Command Line Tools needed. Installing…"
  xcode-select --install || true
  echo "→ Re-run this command when the install finishes."
  exit 1
fi

mkdir -p "$DIR"
cd "$DIR"
echo "→ Downloading…"
curl -fsSL "$REPO/TrackNum.swift" -o TrackNum.swift
echo "→ Building…"
swiftc -O TrackNum.swift -o TrackNum -framework Cocoa

echo ""
echo "✓ Installed to $DIR/TrackNum"
echo ""
echo "Next:"
echo "  1. System Settings → Privacy & Security → Accessibility → enable Terminal"
echo "  2. Privacy & Security → Input Monitoring → enable Terminal"
echo "  3. Run: $DIR/TrackNum"
echo "  4. Tap Control to toggle the numpad"
