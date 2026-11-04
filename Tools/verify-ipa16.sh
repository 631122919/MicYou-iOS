#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Checks the IPA from build-ipa.sh on macOS: iOS 16 deployment target for both bundles, the
# widget extension present, and no hard link to a framework that only exists on iOS 17 or later
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
widget="$app/PlugIns/MicYouWidget.appex"
test -d "$app" || fail "Payload/MicYou.app missing"
test -x "$app/MicYou" || fail "App executable missing"
test -d "$widget" || fail "Widget extension missing"

for bundle in "$app" "$widget"; do
    minos=$(/usr/libexec/PlistBuddy -c 'Print :MinimumOSVersion' "$bundle/Info.plist")
    echo "MinimumOSVersion in $(basename "$bundle"): $minos"
    case "$minos" in
        16.*) ;;
        *) fail "MinimumOSVersion is $minos in $(basename "$bundle"), expected 16.x" ;;
    esac
done

point=$(/usr/libexec/PlistBuddy -c 'Print :NSExtension:NSExtensionPointIdentifier' "$widget/Info.plist")
[ "$point" = "com.apple.widgetkit-extension" ] || fail "Widget extension point is $point"

echo "--- build versions ---"
xcrun vtool -show-build "$app/MicYou"
xcrun vtool -show-build "$widget/MicYouWidget"

echo "--- linked libraries ---"
otool -L "$app/MicYou"
otool -L "$widget/MicYouWidget"

# A strong link to one of these makes dyld abort on iOS 16
for binary in "$app/MicYou" "$widget/MicYouWidget"; do
    for lib in 'libswiftObservation' 'Symbols.framework' '_AppIntents_SwiftUI' 'AppIntents.framework' 'ActivityKit.framework'; do
        if otool -L "$binary" | grep -F "$lib" | grep -qv weak; then
            fail "$lib is still linked in $(basename "$binary"), dyld would fail on iOS 16"
        fi
    done
done

echo "IPA OK: iOS 16 app and widget, nothing iOS 17 only is linked"
