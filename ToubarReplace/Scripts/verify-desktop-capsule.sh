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
validation_dir="$root_dir/.build/capsule-validation"
app_dir="$validation_dir/CapsuleValidation.app"
mkdir -p "$app_dir/Contents/MacOS"
typeset -a sources
sources=(Sources/ToubarReplace/*.swift)
sources=("${(@)sources:#Sources/ToubarReplace/ToubarReplace.swift}")
swiftc -parse-as-library -swift-version 6 -module-name ToubarReplace \
  -I "$build_dir" \
  -Xcc "-fmodule-map-file=$build_dir/TouchBarPrivateAPI.build/module.modulemap" \
  -Xcc "-fmodule-map-file=$build_dir/MirrorFrameProcessing.build/module.modulemap" \
  "${sources[@]}" "$build_dir/ToubarReplace.build/DerivedSources/resource_bundle_accessor.swift" \
  Scripts/verify-desktop-capsule.swift "$build_dir/TouchBarPrivateAPI.build/TouchBarPrivateAPI.m.o" \
  "$build_dir/MirrorFrameProcessing.build/MirrorFrameProcessing.c.o" \
  -o "$app_dir/Contents/MacOS/CapsuleValidation"
cp Packaging/Info.plist "$app_dir/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Set :CFBundleExecutable CapsuleValidation' "$app_dir/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Set :CFBundleIdentifier com.toubarreplace.capsule-validation' "$app_dir/Contents/Info.plist"
/usr/bin/codesign --force --deep --sign - "$app_dir"
report="$validation_dir/report.json"
rm -f "$report" "$validation_dir/stdout.log" "$validation_dir/stderr.log"
/usr/bin/open -n -W --stdout "$validation_dir/stdout.log" --stderr "$validation_dir/stderr.log" \
  "$app_dir" --args "$report"
python3 - "$report" <<'PY'
import json,sys
with open(sys.argv[1]) as stream:
    report=json.load(stream)
print(json.dumps(report,ensure_ascii=False,indent=2))
if report.get('blockers'):
    sys.exit(2)
sys.exit(0 if report['passed'] else 1)
PY
