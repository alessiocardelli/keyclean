#!/bin/sh
# Compila KeyClean.app (swiftc diretto, come BatteryGuard: swift build dei Command Line Tools non va su macOS 26),
# genera l'icona, firma ad-hoc e installa in /Applications.
set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD="$ROOT/.build/manual"
APP="$ROOT/dist/KeyClean.app"
TARGET="arm64-apple-macos13"

rm -rf "$BUILD" "$ROOT/dist"
mkdir -p "$BUILD/AppIcon.iconset" "$APP/Contents/MacOS" "$APP/Contents/Resources"

xcrun swiftc -O -target $TARGET -module-name KeyClean -parse-as-library \
  "$ROOT"/Sources/KeyClean/*.swift -o "$APP/Contents/MacOS/KeyClean"

xcrun swiftc -O -target $TARGET "$ROOT/scripts/tools/make-icon.swift" -o "$BUILD/make-icon"
"$BUILD/make-icon" "$ROOT/Resources/design/app-icon-source.webp" "$BUILD/icon-1024.png"
for size in 16 32 128 256 512; do
  sips -z "$size" "$size" "$BUILD/icon-1024.png" --out "$BUILD/AppIcon.iconset/icon_${size}x${size}.png" >/dev/null
  double=$((size * 2))
  sips -z "$double" "$double" "$BUILD/icon-1024.png" --out "$BUILD/AppIcon.iconset/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$BUILD/AppIcon.iconset" -o "$APP/Contents/Resources/AppIcon.icns"

cp "$ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"
codesign --force --sign - --identifier com.alessiocardelli.keyclean "$APP"

# Installazione: chiude la copia in esecuzione e sostituisce quella in Applicazioni
pkill -x KeyClean 2>/dev/null || true
rm -rf /Applications/KeyClean.app
ditto "$APP" /Applications/KeyClean.app
echo "installata: /Applications/KeyClean.app"
