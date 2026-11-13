#!/bin/bash
# Build an iPhoneOS archive and package it without a certificate or profile.
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p dist build-release
archive_path="$PWD/build-release/CellScope.xcarchive"
log_path="$PWD/build-release/archive.log"
if ! xcodebuild -project CellScope.xcodeproj -scheme CellScope \
    -configuration Release -destination 'generic/platform=iOS' \
    -archivePath "$archive_path" -derivedDataPath "$PWD/build-release/DerivedData" \
    CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO archive > "$log_path" 2>&1; then
    tail -n 50 "$log_path"
    exit 1
fi
python3 scripts/package_unsigned_ipa.py "$archive_path" "$PWD/dist"
