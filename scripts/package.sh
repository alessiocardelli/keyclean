#!/bin/sh
# Impacchetta dist/KeyClean.app (prodotta da build.sh) in dmg e zip versionati, con SHA256SUMS e install.sh, in dist/release.
# Lo zip serve a install.sh (installazione da Terminale).
# Non ricompila e non tocca la copia in /Applications.
set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/dist/KeyClean.app"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist")"
RELEASE="$ROOT/dist/release"
STAGE="$ROOT/.build/dmg-stage"
DMG="$RELEASE/KeyClean-$VERSION.dmg"

rm -rf "$STAGE" "$RELEASE"
mkdir -p "$STAGE" "$RELEASE"
ditto "$APP" "$STAGE/KeyClean.app"
ln -s /Applications "$STAGE/Applications"

hdiutil create -volname "KeyClean" -srcfolder "$STAGE" -fs HFS+ -format UDZO -ov "$DMG" >/dev/null
codesign --force --sign - "$DMG"
ditto -c -k --keepParent "$APP" "$RELEASE/KeyClean-$VERSION.zip"
cp "$ROOT/scripts/install.sh" "$RELEASE/install.sh"
(cd "$RELEASE" && shasum -a 256 "KeyClean-$VERSION.dmg" "KeyClean-$VERSION.zip" > SHA256SUMS)

echo "dmg: $DMG"
cat "$RELEASE/SHA256SUMS"
stat -f "%z byte" "$DMG"
