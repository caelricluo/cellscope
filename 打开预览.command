#!/bin/zsh
set -euo pipefail
cd "${0:A:h}"

preview_app="$PWD/Preview/CellScope 预览.app"
preview_executable="$preview_app/Contents/MacOS/CellScope"
needs_build=false
if [[ ! -f "$preview_executable" ]]; then
    needs_build=true
else
    for source_file in CellScope/**/*.swift Sources/**/*.swift scripts/create_project.py; do
        if [[ "$source_file" -nt "$preview_executable" ]]; then needs_build=true; break; fi
    done
fi
if [[ "$needs_build" == true ]]; then
    mkdir -p build-preview Preview
    python3 scripts/create_project.py --preview
    if ! xcodebuild -project CellScopePreview.xcodeproj -scheme CellScope \
        -configuration Debug -destination 'platform=macOS,variant=Mac Catalyst' \
        -derivedDataPath build-preview CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO \
        build > build-preview/build.log 2>&1; then
        echo '预览编译失败，详细日志：'
        echo "$PWD/build-preview/build.log"
        tail -n 25 build-preview/build.log
        read -r '?按回车关闭'
        exit 1
    fi
    ditto build-preview/Build/Products/Debug-maccatalyst/CellScope.app "$preview_app"
fi
/usr/bin/open "$preview_app"
