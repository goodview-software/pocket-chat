#!/bin/sh
# Test headless : deux instances sur la même machine se découvrent, échangent un message et un fichier de 5 Mo (sha256).
cd "$(dirname "$0")/.."
T=${TMPDIR:-/tmp}/pocketchat-test; rm -rf "$T"; mkdir -p "$T/a" "$T/b"
G="flatpak run org.godotengine.Godot --headless --path ."
CHAT_TEST=b CHAT_NAME=Bob CHAT_MASCOT=2 CHAT_DATA=$T/b CHAT_DL=$T/b/dl CHAT_TCP=5225 CHAT_UDP=5226 CHAT_PEERS=127.0.0.1:5216 $G > $T/b.log 2>&1 &
PB=$!
CHAT_TEST=a CHAT_NAME=Alice CHAT_MASCOT=5 CHAT_DATA=$T/a CHAT_DL=$T/a/dl CHAT_TCP=5215 CHAT_UDP=5216 CHAT_PEERS=127.0.0.1:5226 $G > $T/a.log 2>&1
RA=$?
wait $PB; RB=$?
grep -h "^TEST\|^A:\|^B:\|SCRIPT ERROR\|ERROR" $T/a.log $T/b.log
[ $RA = 0 ] && [ $RB = 0 ] && echo "OK : test réussi" || { echo "ÉCHEC ($RA/$RB)"; exit 1; }
