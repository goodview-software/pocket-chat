#!/bin/sh
# Test headless du contact « Moi » : une seule instance s'envoie un message et un fichier de 3 Mo (bouclage local).
cd "$(dirname "$0")/.."
T=${TMPDIR:-/tmp}/pocketchat-self; rm -rf "$T"; mkdir -p "$T"
CHAT_TEST=s CHAT_NAME=Solo CHAT_MASCOT=1 CHAT_DATA=$T CHAT_DL=$T/dl CHAT_TCP=5245 CHAT_UDP=5246 flatpak run org.godotengine.Godot --headless --path . 2>&1 | grep "^TEST\|^S:\|SCRIPT ERROR\|ERROR"
