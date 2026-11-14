#!/usr/bin/env bash
set -euo pipefail
TASK_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$TASK_ROOT/android"
./gradlew :core:test :app:lintPreview :app:assemblePreview :app:assembleRelease
python3 "$TASK_ROOT/scripts/package_android.py"
