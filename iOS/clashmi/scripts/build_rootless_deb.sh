#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd -P)"
IOS_CLASHMI="$ROOT/iOS/clashmi"
IOS_DIR="$IOS_CLASHMI/ios"
DIST="$ROOT/dist"
VERSION=""

usage() {
  cat <<EOF
Usage: $0 [-v <version>] [-o <output.deb>]

Build clashmi (with mihomo-cns core) as a rootless iOS jailbreak .deb on macOS.

Requires: Xcode, Go, Flutter, gomobile, ldid, CocoaPods.

Options:
  -v  Package version (default: read from built app Info.plist)
  -o  Output .deb path (default: $DIST/clashmi-rootless-arm64.deb)
  -h  Show this help
EOF
}

OUT="$DIST/clashmi-rootless-arm64.deb"

while getopts "v:o:h" opt; do
  case "$opt" in
    v) VERSION="$OPTARG" ;;
    o) OUT="$OPTARG" ;;
    h) usage; exit 0 ;;
    *) usage; exit 1 ;;
  esac
done

for tool in go flutter pod ldid gomobile xcodebuild; do
  command -v "$tool" >/dev/null 2>&1 || { echo "error: required tool not found: $tool" >&2; exit 1; }
done

export PATH="$PATH:$(go env GOPATH)/bin"
export GOPROXY="${GOPROXY:-https://goproxy.cn,direct}"

echo "==> gomobile bind Libclash.xcframework (mihomo-cns core with cns protocol)"
gomobile init
gomobile bind \
  -target=ios \
  -o "$IOS_CLASHMI/bind/apple/Libclash.xcframework" \
  github.com/metacubex/mihomo/iOS/libclash

echo "==> flutter pub get"
(cd "$IOS_CLASHMI" && flutter pub get)

echo "==> pod install"
(cd "$IOS_DIR" && pod install)

echo "==> xcodebuild Release (no codesign)"
set +e
(
  cd "$IOS_DIR"
  xcodebuild -workspace Runner.xcworkspace -scheme Runner -configuration Release \
    -sdk iphoneos -destination 'generic/platform=iOS' \
    SYMROOT="$PWD/build" CODE_SIGNING_ALLOWED=NO build > /tmp/clashmi-xcb.log 2>&1
)
XCB=$?
set -e
if [ $XCB -ne 0 ]; then
  echo "=== ERROR DIAGNOSTICS ==="
  grep -B5 -A25 "does not conform\|error:\|BUILD FAILED" /tmp/clashmi-xcb.log | head -300 || true
  echo "=== END ==="
  exit $XCB
fi

APP=$(find "$IOS_DIR/build/Release-iphoneos" -maxdepth 1 -name "*.app" | head -1)
[ -n "$APP" ] || { echo "error: no .app bundle found in Release-iphoneos" >&2; exit 1; }
echo "app bundle: $APP"

echo "==> sign Mach-O with ldid"
sed 's/\$(AppIdentifierPrefix)//g' "$IOS_DIR/Runner/Runner.entitlements" > /tmp/ent-runner.plist
sed 's/\$(AppIdentifierPrefix)//g' "$IOS_DIR/clashmiWidget/clashmiWidgetExtension.entitlements" > /tmp/ent-widget.plist
sed 's/\$(AppIdentifierPrefix)//g' "$IOS_DIR/clashmiService/clashmiService.entitlements" > /tmp/ent-service.plist
find "$APP" -type f -print0 | while IFS= read -r -d '' f; do
  if file "$f" | grep -q 'Mach-O'; then
    case "$f" in
      *PlugIns/clashmiWidgetExtension.appex/*)
        ldid -S/tmp/ent-widget.plist "$f" ;;
      *PlugIns/clashmiService.appex/*)
        ldid -S/tmp/ent-service.plist "$f" ;;
      *"$APP/Clash Mi")
        ldid -S/tmp/ent-runner.plist "$f" ;;
      *)
        ldid -S "$f" ;;
    esac
  fi
done
ldid -S/tmp/ent-runner.plist "$APP"

echo "==> package rootless deb"
if [ -n "$VERSION" ]; then
  "$IOS_CLASHMI/scripts/package_rootless_deb.sh" -a "$APP" -o "$OUT" -v "$VERSION"
else
  "$IOS_CLASHMI/scripts/package_rootless_deb.sh" -a "$APP" -o "$OUT"
fi

echo "done: $OUT"
