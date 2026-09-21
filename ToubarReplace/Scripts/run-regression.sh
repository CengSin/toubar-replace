#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
PACKAGE_DIR="$(cd "$SCRIPT_DIR/.." && pwd -P)"
cd "$PACKAGE_DIR"

# 1. Swift 注释合规性静态检测
echo "==> [1/2] 正在运行 Swift 代码注释合规检测..."
"$SCRIPT_DIR/check-comments.sh" --check

# 2. 编译与烟雾回归测试
echo "==> [2/2] 正在运行 ToubarReplace 冒烟回归测试..."
cache_root=/private/tmp/ToubarReplaceRegressionCache
mkdir -p "$cache_root/clang-module-cache"
mkdir -p "$cache_root/swiftpm-module-cache"

export CLANG_MODULE_CACHE_PATH="$cache_root/clang-module-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="$cache_root/swiftpm-module-cache"

legacy_sdk=/Library/Developer/CommandLineTools/SDKs/MacOSX15.4.sdk
if [[ -z "${SDKROOT:-}" && -d "$legacy_sdk" ]]; then
    export SDKROOT="$legacy_sdk"
fi

exec swift run --disable-sandbox ToubarReplace --smoke-test

