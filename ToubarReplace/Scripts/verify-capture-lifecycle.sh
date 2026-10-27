#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
PACKAGE_DIR="$(cd "$SCRIPT_DIR/.." && pwd -P)"
cd "$PACKAGE_DIR"

cache_root=/private/tmp/ToubarReplaceRegressionCache
mkdir -p "$cache_root/clang-module-cache" "$cache_root/swiftpm-module-cache"
export CLANG_MODULE_CACHE_PATH="$cache_root/clang-module-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="$cache_root/swiftpm-module-cache"
export SDKROOT="${SDKROOT:-$(xcrun --sdk macosx --show-sdk-path)}"

swift build --disable-sandbox
build_dir="$(swift build --disable-sandbox --show-bin-path)"
probe_dir="$(mktemp -d "${TMPDIR:-/tmp}/ToubarReplaceCaptureProbe.XXXXXX")"
trap 'rm -rf "$probe_dir"' EXIT

xcrun swiftc -j1 -parse-as-library -module-name TouchBarCaptureLifecycleVerifier \
    -swift-version 6 -target "$(uname -m)-apple-macosx14.0" \
    -module-cache-path "$build_dir/ModuleCache" \
    -I "$build_dir/TouchBarPrivateAPI.build" \
    -Xcc "-fmodule-map-file=$build_dir/TouchBarPrivateAPI.build/module.modulemap" \
    -Xcc -I -Xcc "$PACKAGE_DIR/Sources/TouchBarPrivateAPI/include" \
    "$PACKAGE_DIR/Sources/ToubarReplace/TouchBarDisplayStream.swift" \
    "$PACKAGE_DIR/Sources/ToubarReplace/TouchBarCapture.swift" \
    "$SCRIPT_DIR/verify-capture-lifecycle.swift" \
    "$build_dir/TouchBarPrivateAPI.build/TouchBarPrivateAPI.m.o" \
    -framework AppKit -framework CoreGraphics -framework CoreImage -framework IOSurface \
    -o "$probe_dir/verify-capture-lifecycle"

"$probe_dir/verify-capture-lifecycle" "$@"
