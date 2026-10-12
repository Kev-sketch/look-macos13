#!/bin/bash
# Build the Look macOS app without Xcode, for macOS 13.x (Ventura) hosts that
# only have the Command Line Tools and an older SDK (13.3).
#
# Usage:
#   scripts/build-macos-clt.sh [debug|release]     # default: debug
#
# Produces: build-clt/Look.app
#
# This is the local/CI Ventura+Intel path only. The canonical release build
# stays on Xcode 26.3 (apps/macos/LauncherApp/look-app.xcodeproj); the Swift
# sources compile under both paths, with the macOS-13 SDK differences gated on
# the LOOK_VENTURA_SDK13 compilation condition passed below.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

PROFILE="${1:-debug}"
case "$PROFILE" in
  debug)   SWIFT_OPT=() ;;
  release) SWIFT_OPT=(-O) ;;
  *) echo "usage: $0 [debug|release]" >&2; exit 2 ;;
esac
# bash 3.2 (macOS /bin/bash) + set -u: an empty array counts as unbound, so
# expansions go through this guard.
SWIFT_OPTS=(${SWIFT_OPT[@]+"${SWIFT_OPT[@]}"})

APP="build-clt/Look.app"
MACOS_DIR="$APP/Contents/MacOS"
RESOURCES_DIR="$APP/Contents/Resources"
SOURCES_DIR="apps/macos/LauncherApp/look-app"
ENTITLEMENTS="$SOURCES_DIR/Look.entitlements"
FFI_LIB_RELEASE="bridge/ffi/target/x86_64-apple-darwin/release/liblook_ffi.a"

# rustup's cargo is not on the default PATH on a clean CLT shell.
export PATH="$HOME/.cargo/bin:$PATH"

echo "==> Cleaning $APP"
rm -rf "$APP"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

# ── Rust FFI static library ────────────────────────────────────────────────
if [ ! -f "$FFI_LIB_RELEASE" ]; then
  echo "==> Building the Rust FFI staticlib (x86_64-apple-darwin, release)"
  export MACOSX_DEPLOYMENT_TARGET="${MACOSX_DEPLOYMENT_TARGET:-13.0}"
  cargo build --release --target x86_64-apple-darwin \
    --manifest-path bridge/ffi/Cargo.toml
fi
FFI_LIB="$FFI_LIB_RELEASE"
[ -f "$FFI_LIB" ] || { echo "error: $FFI_LIB missing after FFI build" >&2; exit 1; }
echo "==> Using FFI staticlib: $FFI_LIB"

# ── Swift sources ──────────────────────────────────────────────────────────
# Every .swift file under look-app. (LauncherLogicTests lives beside look-app,
# not inside it, so there is nothing test-only to exclude here.)
SOURCES=()
while IFS= read -r f; do SOURCES+=("$f"); done < <(find "$SOURCES_DIR" -name '*.swift' | LC_ALL=C sort)
echo "==> Compiling ${#SOURCES[@]} Swift files (${PROFILE})"

# SDK 13.3: libproc.h (proc_pidinfo, proc_name, proc_pid_rusage,
# proc_pidfdinfo) is not part of the Darwin module. Expose the SDK header
# through a side module so `import CltLibproc` (guarded by canImport, skipped on
# newer SDKs where Darwin already exports these) resolves.
SDKROOT="$(xcrun --sdk macosx --show-sdk-path)"
MODULEMAP="build-clt/CltLibproc.modulemap"
if [ -f "$SDKROOT/usr/include/libproc.h" ]; then
  cat > "$MODULEMAP" <<MAP
module CltLibproc [system] {
    header "$SDKROOT/usr/include/libproc.h"
    export *
}
MAP
  EXTRA_CC_OPTS=(-Xcc -fmodule-map-file="$ROOT/$MODULEMAP")
else
  EXTRA_CC_OPTS=()
fi

swiftc -parse-as-library -swift-version 5 \
  -target x86_64-apple-macosx13.0 \
  -D LOOK_VENTURA_SDK13 \
  -strict-concurrency=minimal \
  ${SWIFT_OPTS[@]+"${SWIFT_OPTS[@]}"} \
  ${EXTRA_CC_OPTS[@]+"${EXTRA_CC_OPTS[@]}"} \
  -o "$MACOS_DIR/Look" \
  "${SOURCES[@]}" \
  -Xlinker -force_load -Xlinker "$ROOT/$FFI_LIB" \
  -lsqlite3

# ── App icon ───────────────────────────────────────────────────────────────
# The appiconset PNGs are already iconutil-compatible names; stage a temp
# iconset and compile it to an icns.
ICONSET_SRC="$SOURCES_DIR/Assets.xcassets/AppIcon.appiconset"
if [ -d "$ICONSET_SRC" ]; then
  ICONSET="build-clt/AppIcon.iconset"
  rm -rf "$ICONSET"
  mkdir -p "$ICONSET"
  cp "$ICONSET_SRC"/*.png "$ICONSET"/
  iconutil -c icns "$ICONSET" -o "$RESOURCES_DIR/AppIcon.icns"
fi

# ── Info.plist ─────────────────────────────────────────────────────────────
# Strings mirror apps/macos/LauncherApp's INFOPLIST_KEY_* entries (and the
# shipped Look.app). LSMinimumSystemVersion is 13.0 for this bundle: the
# Xcode path stays on the current release floor.
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleDevelopmentRegion</key>
	<string>en</string>
	<key>CFBundleDisplayName</key>
	<string>Look</string>
	<key>CFBundleExecutable</key>
	<string>Look</string>
	<key>CFBundleIconFile</key>
	<string>AppIcon</string>
	<key>CFBundleIdentifier</key>
	<string>noah-code.Look</string>
	<key>CFBundleInfoDictionaryVersion</key>
	<string>6.0</string>
	<key>CFBundleName</key>
	<string>Look</string>
	<key>CFBundlePackageType</key>
	<string>APPL</string>
	<key>CFBundleShortVersionString</key>
	<string>0.7.2</string>
	<key>CFBundleSupportedPlatforms</key>
	<array>
		<string>MacOSX</string>
	</array>
	<key>CFBundleVersion</key>
	<string>0.7.2</string>
	<key>LSMinimumSystemVersion</key>
	<string>13.0</string>
	<key>LSUIElement</key>
	<true/>
	<key>NSAppleEventsUsageDescription</key>
	<string>Look uses Finder to empty the Trash and read how many items it contains.</string>
	<key>NSBluetoothAlwaysUsageDescription</key>
	<string>Look reads and toggles Bluetooth power from the launcher's quick actions.</string>
	<key>NSCalendarsUsageDescription</key>
	<string>Look creates and edits calendar events when you ask it to.</string>
	<key>NSCalendarsFullAccessUsageDescription</key>
	<string>Look creates and edits calendar events when you ask it to.</string>
	<key>NSContactsUsageDescription</key>
	<string>Look finds who to message or FaceTime when you type a name.</string>
	<key>NSRemindersUsageDescription</key>
	<string>Look creates and completes reminders when you ask it to.</string>
	<key>NSRemindersFullAccessUsageDescription</key>
	<string>Look creates and completes reminders when you ask it to.</string>
</dict>
</plist>
PLIST

printf 'APPL????' > "$APP/Contents/PkgInfo"

# No Assets.car: the app references no asset-catalog images or colors by name
# (only SF Symbols), and AccentColor.colorset is unreferenced.

# ── Ad-hoc codesign ────────────────────────────────────────────────────────
# Ad-hoc is expected for local builds; the CI/release path keeps Developer ID
# signing untouched.
codesign --force --sign - --entitlements "$ENTITLEMENTS" "$APP"

echo
echo "==> Built $APP ($PROFILE)"
file "$MACOS_DIR/Look"
ls -lh "$APP/Contents/Resources"
