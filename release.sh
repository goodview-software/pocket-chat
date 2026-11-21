#!/bin/sh
# Publie une version : ./release.sh 0.2.0 "Notes"
# Exporte le zip Linux (avec l'APK à côté) et l'APK.
set -e
V="$1"; NOTES="${2:-Version $1}"
[ -n "$V" ] || { echo "usage: $0 <version> [notes]"; exit 1; }
cd "$(dirname "$0")"
REPO=goodview-software/pocket-chat
GODOT="flatpak run org.godotengine.Godot"
OUT=build/release; rm -rf "$OUT"; mkdir -p "$OUT" build/linux

sed -i "s/^const APP_VERSION := .*/const APP_VERSION := \"$V\"/" main.gd
sed -i "s/^version\/name=.*/version\/name=\"$V\"/" export_presets.cfg
$GODOT --headless --path . --export-debug "Android" "$OUT/PocketChat.apk"
$GODOT --headless --path . --export-release "Linux" build/linux/PocketChat.x86_64
cp "$OUT/PocketChat.apk" build/linux/pocket-chat.apk
cp icon.png build/linux/
rm -rf build/PocketChat && cp -r build/linux build/PocketChat
(cd build && zip -qr "release/PocketChat-linux.zip" PocketChat) && rm -rf build/PocketChat
rm -f "$OUT"/*.idsig

git add -A && git commit -qm "Version $V" || true
git tag -f "v$V" && git push -q origin HEAD && git push -qf origin "v$V"
gh release create "v$V" --repo "$REPO" --title "Pocket Chat $V" --notes "$NOTES" "$OUT"/*
echo "Publié : https://github.com/$REPO/releases/tag/v$V"
