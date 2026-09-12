#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
swift build -c release
bin_path="$(swift build -c release --show-bin-path)"
mkdir -p "$PWD/build"
staging_path="$(mktemp -d "$PWD/build/.package.XXXXXX")"
app_path="$staging_path/Mal.app"
mkdir -p "$app_path/Contents/MacOS" "$app_path/Contents/Resources"
cp "$bin_path/Mal" "$app_path/Contents/MacOS/Mal"
if [ -d "$app_path/Contents/Resources/Mal_MalApp.bundle" ]; then
    chmod -R u+w "$app_path/Contents/Resources/Mal_MalApp.bundle"
fi
cp -R "$bin_path/Mal_MalApp.bundle" "$app_path/Contents/Resources/"
chmod -R u+w "$app_path/Contents/Resources/Mal_MalApp.bundle"
cat > "$app_path/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>Mal</string>
<key>CFBundleIdentifier</key><string>com.mal.korean</string>
<key>CFBundleName</key><string>Mal</string>
<key>CFBundleDisplayName</key><string>Mal (말)</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>0.1.0</string>
<key>CFBundleVersion</key><string>1</string>
<key>LSMinimumSystemVersion</key><string>26.0</string>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
codesign --force --deep --sign - "$app_path"
codesign --verify --deep --strict "$app_path"
# Publish only after the complete package verifies; retain the prior app.
if [ -d "$PWD/build/Mal.app" ]; then
    previous_path="$PWD/build/Mal.previous.$(date +%s).app"
    mv "$PWD/build/Mal.app" "$previous_path"
fi
mv "$app_path" "$PWD/build/Mal.app"
rmdir "$staging_path"
echo "$PWD/build/Mal.app"
