#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="${0:A:h}"
PROJECT_DIR="${SCRIPT_DIR:h}"
BUILD_DIR="$PROJECT_DIR/.build/release"
APP_DIR="$PROJECT_DIR/dist/FocusGarden.app"
CONTENTS_DIR="$APP_DIR/Contents"
GUARDIAN_APP_DIR="$CONTENTS_DIR/Library/LoginItems/FocusGardenGuardian.app"
GUARDIAN_CONTENTS_DIR="$GUARDIAN_APP_DIR/Contents"

cd "$PROJECT_DIR"
swift build -c release
swift "$PROJECT_DIR/Scripts/generate-icon.swift"

mkdir -p "$CONTENTS_DIR/MacOS" "$CONTENTS_DIR/Resources"
mkdir -p "$GUARDIAN_CONTENTS_DIR/MacOS"
cp "$BUILD_DIR/FocusGarden" "$CONTENTS_DIR/MacOS/FocusGarden"
cp "$PROJECT_DIR/Resources/Info.plist" "$CONTENTS_DIR/Info.plist"
cp "$PROJECT_DIR/Resources/FocusGarden.icns" "$CONTENTS_DIR/Resources/FocusGarden.icns"
cp -R "$PROJECT_DIR/Resources/AmbientSounds" "$CONTENTS_DIR/Resources/AmbientSounds"
cp "$BUILD_DIR/FocusGardenGuardian" "$GUARDIAN_CONTENTS_DIR/MacOS/FocusGardenGuardian"
cp "$PROJECT_DIR/Resources/Guardian-Info.plist" "$GUARDIAN_CONTENTS_DIR/Info.plist"

codesign --force --deep --sign - "$GUARDIAN_APP_DIR"
codesign --force --deep --sign - "$APP_DIR"
echo "$APP_DIR"
