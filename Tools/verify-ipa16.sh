#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Checks the IPA from build-ipa.sh on macOS: iOS 16 deployment target, no extension, and no
# hard link to a framework that only exists on iOS 17 or later, which would crash at launch
set -euo pipefail
cd "$(dirname "$0")/.."

fail() {
    echo "::error::$1"
    exit 1
}

check=$(mktemp -d)
trap 'rm -rf "$check"' EXIT
unzip -q xtool/MicYou.ipa -d "$check"
app="$check/Payload/MicYou.app"
test -d "$app" || fail "Payload/MicYou.app missing"
test -x "$app/MicYou" || fail "Executable missing"

minos=$(/usr/libexec/PlistBuddy -c 'Print :MinimumOSVersion' "$app/Info.plist")
echo "MinimumOSVersion: $minos"
case "$minos" in
    16.*) ;;
    *) fail "MinimumOSVersion is $minos, expected 16.x" ;;
esac

echo "--- load commands ---"
xcrun vtool -show-build "$app/MicYou"

echo "--- linked libraries ---"
otool -L "$app/MicYou"

if [ -d "$app/PlugIns" ]; then
    fail "The IPA still contains extensions: $(ls "$app/PlugIns")"
fi

# A strong link to one of these makes dyld abort on iOS 16
for lib in 'libswiftObservation' 'Symbols.framework' '_AppIntents_SwiftUI' 'AppIntents.framework' 'ActivityKit.framework' 'WidgetKit.framework'; do
    if otool -L "$app/MicYou" | grep -F "$lib" | grep -qv weak; then
        fail "$lib is still linked, dyld would fail on iOS 16"
    fi
done

echo "IPA OK: iOS $minos, no extension, nothing iOS 17 only is linked"
