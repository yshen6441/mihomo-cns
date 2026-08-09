#!/bin/bash
set -euo pipefail

usage() {
  cat <<EOF
Usage: $0 -a <ClashMi.app> -o <output.deb> [-v <version>] [-p <package-id>]

Build a rootless iOS jailbreak .deb from a signed .app bundle.

Options:
  -a  Path to the signed .app bundle (required)
  -o  Output .deb path (required)
  -v  Package version (default: read from Info.plist CFBundleShortVersionString)
  -p  Dpkg package id (default: com.nebula.clashmi)
  -h  Show this help
EOF
}

APP=""
OUT=""
VERSION=""
PACKAGE_ID="com.nebula.clashmi"

while getopts "a:o:v:p:h" opt; do
  case "$opt" in
    a) APP="$OPTARG" ;;
    o) OUT="$OPTARG" ;;
    v) VERSION="$OPTARG" ;;
    p) PACKAGE_ID="$OPTARG" ;;
    h) usage; exit 0 ;;
    *) usage; exit 1 ;;
  esac
done

[ -z "$APP" ] && { echo "error: -a is required" >&2; usage; exit 1; }
[ -z "$OUT" ] && { echo "error: -o is required" >&2; usage; exit 1; }
[ -d "$APP" ] || { echo "error: app bundle not found: $APP" >&2; exit 1; }

PLIST="$APP/Info.plist"

if [ -z "$VERSION" ]; then
  if [ -x /usr/libexec/PlistBuddy ]; then
    VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$PLIST" 2>/dev/null || echo "1.0.0")
  else
    VERSION=$(defaults read "$(pwd -P)/${APP}/Info" CFBundleShortVersionString 2>/dev/null || echo "1.0.0")
  fi
fi

APP_NAME="ClashMi"
JB_ROOT="var/jb"
OUT_ABS="$(cd "$(dirname "$OUT")" && pwd -P)/$(basename "$OUT")"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

PKG_ROOT="$TMP/pkgroot"
CTRL_DIR="$TMP/control"
mkdir -p "$PKG_ROOT/$JB_ROOT/Applications" "$CTRL_DIR"

cp -R "$APP" "$PKG_ROOT/$JB_ROOT/Applications/$APP_NAME.app"

SIZE_KB=$(du -sk "$PKG_ROOT" | awk '{print $1}')

cat > "$CTRL_DIR/control" <<EOF
Package: $PACKAGE_ID
Name: Clash Mi
Version: $VERSION
Architecture: iphoneos-arm64
Maintainer: KaringX
Section: Networking
Priority: optional
Installed-Size: $SIZE_KB
Depends: firmware (>= 15.0)
Description: Clash Mi rootless jailbreak package with mihomo-cns core
Homepage: https://github.com/metacubex/mihomo
EOF

cat > "$CTRL_DIR/postinst" <<'EOF'
#!/bin/sh
if [ -x /var/jb/usr/bin/uicache ]; then
  /var/jb/usr/bin/uicache -p /var/jb/Applications/ClashMi.app 2>/dev/null || true
fi
exit 0
EOF

cat > "$CTRL_DIR/prerm" <<'EOF'
#!/bin/sh
if [ -x /var/jb/usr/bin/uicache ]; then
  /var/jb/usr/bin/uicache -u /var/jb/Applications/ClashMi.app 2>/dev/null || true
fi
exit 0
EOF

chmod 755 "$CTRL_DIR/postinst" "$CTRL_DIR/prerm"

echo "2.0" > "$TMP/debian-binary"
(cd "$CTRL_DIR" && tar -czf "$TMP/control.tar.gz" control postinst prerm)
(cd "$PKG_ROOT" && tar -czf "$TMP/data.tar.gz" "$JB_ROOT")

ar -q "$OUT_ABS" "$TMP/debian-binary" "$TMP/control.tar.gz" "$TMP/data.tar.gz"

echo "built rootless deb: $OUT_ABS"
