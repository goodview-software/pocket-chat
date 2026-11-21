#!/bin/sh
# Test : un vrai clic de souris sur une carte de contact (le contact « Moi ») ouvre la conversation.
cd "$(dirname "$0")/.."
T=${TMPDIR:-/tmp}/pocketchat-click; rm -rf "$T"; mkdir -p "$T"
CHAT_TEST=c CHAT_NAME=Solo CHAT_MASCOT=1 CHAT_DATA=$T CHAT_DL=$T/dl CHAT_TCP=5265 CHAT_UDP=5266 flatpak run org.godotengine.Godot --path . 2>&1 | grep "^TEST\|^C:\|SCRIPT ERROR"
