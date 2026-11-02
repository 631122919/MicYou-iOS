#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Builds the unsigned release IPA, no extensions in this fork
set -euo pipefail
cd "$(dirname "$0")/.."
xtool dev build -c release --ipa

# xtool stores every file uncompressed, deflating them halves the download
ipa="$PWD/xtool/MicYou.ipa"
payload=$(mktemp -d)
trap 'rm -rf "$payload"' EXIT
unzip -q "$ipa" -d "$payload"
rm "$ipa"
(cd "$payload" && zip -q -r -9 -y -X "$ipa" Payload)
ls -l xtool/*.ipa
echo "Wrote $ipa"
