#!/bin/zsh
set -euo pipefail

root_dir="$(cd "$(dirname "$0")/.." && pwd -P)"
cd "$root_dir"
cache_root=/private/tmp/ToubarReplaceRegressionCache
mkdir -p "$cache_root/clang-module-cache" "$cache_root/swiftpm-module-cache"
export CLANG_MODULE_CACHE_PATH="$cache_root/clang-module-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="$cache_root/swiftpm-module-cache"
export SDKROOT="${SDKROOT:-$(xcrun --sdk macosx --show-sdk-path)}"

swift build --disable-sandbox
build_dir="$(swift build --disable-sandbox --show-bin-path)"
validation_dir="$root_dir/.build/mirror-validation"
mkdir -p "$validation_dir"
clang -fsanitize=address,undefined -fno-omit-frame-pointer -g \
  -I Sources/MirrorFrameProcessing/include \
  Sources/MirrorFrameProcessing/MirrorFrameProcessing.c Scripts/verify-mirror-rendering.c \
  -o "$validation_dir/native-safety"
UBSAN_OPTIONS=halt_on_error=1 "$validation_dir/native-safety"
swiftc -module-cache-path "$CLANG_MODULE_CACHE_PATH" -I "$build_dir" \
  -Xcc "-fmodule-map-file=$build_dir/MirrorFrameProcessing.build/module.modulemap" \
  Sources/ToubarReplace/MirrorGlassFrameRenderer.swift Scripts/verify-mirror-rendering.swift \
  "$build_dir/MirrorFrameProcessing.build/MirrorFrameProcessing.c.o" \
  -o "$validation_dir/performance"
"$validation_dir/performance" "$validation_dir/performance.json" "$@"
