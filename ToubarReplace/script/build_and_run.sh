#!/bin/zsh
set -euo pipefail

mode="${1:-run}"
root_dir="$(cd "$(dirname "$0")/.." && pwd -P)"
cd "$root_dir"

case "$mode" in
  run|--verify|--debug|--logs|--telemetry) ;;
  *) print -u2 "usage: $0 [--verify|--debug|--logs|--telemetry]"; exit 2 ;;
esac

"$root_dir/Scripts/check-comments.sh" --check
cache_root=/private/tmp/ToubarReplaceRegressionCache
mkdir -p "$cache_root/clang-module-cache" "$cache_root/swiftpm-module-cache"
export CLANG_MODULE_CACHE_PATH="$cache_root/clang-module-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="$cache_root/swiftpm-module-cache"
export SDKROOT="${SDKROOT:-$(xcrun --sdk macosx --show-sdk-path)}"

swift build --disable-sandbox
build_dir="$(swift build --disable-sandbox --show-bin-path)"
app_dir="$root_dir/dist/ToubarReplace.app"
/usr/bin/pkill -x ToubarReplace >/dev/null 2>&1 || true
mkdir -p "$app_dir/Contents/MacOS" "$app_dir/Contents/Resources/AgentIcons"
cp "$build_dir/ToubarReplace" "$app_dir/Contents/MacOS/ToubarReplace"
cp "$root_dir/Packaging/Info.plist" "$app_dir/Contents/Info.plist"
cp "$root_dir/Sources/ToubarReplace/Resources/AgentIcons/"*.png "$app_dir/Contents/Resources/AgentIcons/"
if [[ -f "$root_dir/Resources/AppIcon-source.png" ]]; then
  cp "$root_dir/Resources/AppIcon-source.png" "$app_dir/Contents/Resources/AppIcon.png"
fi
/usr/bin/codesign --force --deep --sign - "$app_dir"

case "$mode" in
  --debug) exec /usr/bin/lldb -- "$app_dir/Contents/MacOS/ToubarReplace" ;;
  --logs)
    /usr/bin/open -n "$app_dir"
    exec /usr/bin/log stream --info --style compact --predicate 'process == "ToubarReplace"'
    ;;
  --telemetry)
    /usr/bin/open -n "$app_dir"
    exec /usr/bin/log stream --info --style compact --predicate 'subsystem == "com.toubarreplace.app"'
    ;;
  --verify)
    /usr/bin/open -n "$app_dir"
    /bin/sleep 1
    /usr/bin/pgrep -x ToubarReplace
    ;;
  run) /usr/bin/open -n "$app_dir" ;;
esac
