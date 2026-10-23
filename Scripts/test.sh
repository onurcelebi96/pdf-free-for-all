#!/bin/bash
set -euo pipefail

project_root="$(cd "$(dirname "$0")/.." && pwd)"
developer_directory="$(xcode-select -p)"
testing_frameworks="$developer_directory/Library/Developer/Frameworks"
testing_runtime="$developer_directory/Library/Developer/usr/lib"

cd "$project_root"
if [ -d "$testing_frameworks/Testing.framework" ]; then
    DYLD_FRAMEWORK_PATH="$testing_frameworks${DYLD_FRAMEWORK_PATH:+:$DYLD_FRAMEWORK_PATH}" swift test \
        -Xswiftc -F -Xswiftc "$testing_frameworks" \
        -Xlinker -F -Xlinker "$testing_frameworks" \
        -Xlinker -rpath -Xlinker "$testing_frameworks" \
        -Xlinker -rpath -Xlinker "$testing_runtime"
else
    swift test
fi
