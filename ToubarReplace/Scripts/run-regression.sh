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

export SDKROOT="${SDKROOT:-$(xcrun --sdk macosx --show-sdk-path)}"
sdk_version=$(/usr/libexec/PlistBuddy -c 'Print :Version' "$SDKROOT/SDKSettings.plist")
if (( ${sdk_version%%.*} < 26 )); then
    echo "error: ToubarReplace 毛玻璃主题需要 macOS 26 或更高版本 SDK（当前 $sdk_version）；最低运行版本仍为 macOS 14。" >&2
    exit 1
fi

exec swift run --disable-sandbox ToubarReplace --smoke-test
