#!/bin/zsh
set -euo pipefail
cd "${0:A:h}"

preview_app="$PWD/Preview/cellscope.app"
preview_executable="$preview_app/Contents/MacOS/cellscope"
needs_build=false
if [[ ! -f "$preview_executable" ]]; then
    needs_build=true
else
    for source_file in cellscope/**/*.swift Sources/**/*.swift scripts/create_project.py; do
        if [[ "$source_file" -nt "$preview_executable" ]]; then needs_build=true; break; fi
    done
fi
if [[ "$needs_build" == true ]]; then
    mkdir -p build-preview Preview
    python3 scripts/create_project.py --preview
    if ! xcodebuild -project cellscopePreview.xcodeproj -scheme cellscope \
        -configuration Debug -destination 'platform=macOS,variant=Mac Catalyst' \
        -derivedDataPath build-preview CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO \
        build > build-preview/build.log 2>&1; then
        echo 'Preview build failed. Build log:'
        echo "$PWD/build-preview/build.log"
        tail -n 25 build-preview/build.log
        read -r '?Press Return to close'
        exit 1
    fi
    ditto build-preview/Build/Products/Debug-maccatalyst/cellscope.app "$preview_app"
fi
/usr/bin/open "$preview_app"
