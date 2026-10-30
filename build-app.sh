#!/bin/zsh
# 릴리스 빌드 → build/36NOCH.app 으로 포장
set -e
cd "$(dirname "$0")"
VERSION="0.0.8"
APP="build/36NOCH.app"

swift build -c release
BIN="$(swift build -c release --show-bin-path)"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN/NOCH" "$APP/Contents/MacOS/NOCH"
cp Resources/menubarIcon.png "$APP/Contents/Resources/menubarIcon.png"

# 앱 아이콘: Resources/AppIcon.png → AppIcon.icns
ICONSET="build/AppIcon.iconset"
rm -rf "$ICONSET"; mkdir -p "$ICONSET"
for s in 16 32 128 256 512; do
    sips -z $s $s Resources/AppIcon.png --out "$ICONSET/icon_${s}x${s}.png" >/dev/null
    sips -z $((s*2)) $((s*2)) Resources/AppIcon.png --out "$ICONSET/icon_${s}x${s}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"
rm -rf "$ICONSET"
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key><string>NOCH</string>
    <key>CFBundleIdentifier</key><string>com.artbrain.noch</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>CFBundleName</key><string>36NOCH</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>$VERSION</string>
    <key>CFBundleVersion</key><string>$VERSION</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>LSUIElement</key><true/>
    <key>NSHighResolutionCapable</key><true/>
    <key>NSCalendarsFullAccessUsageDescription</key><string>노치 팝업에 구글 캘린더 일정을 보여 주려고 캘린더를 읽습니다.</string>
    <key>NSCalendarsUsageDescription</key><string>노치 팝업에 구글 캘린더 일정을 보여 주려고 캘린더를 읽습니다.</string>
</dict>
</plist>
PLIST
# 서명: Apple Development 인증서가 있으면 그것으로. ad-hoc 서명은 빌드마다 달라져서 업데이트할 때마다
# 캘린더 권한을 다시 묻는다. 인증서가 같으면 권한이 이어진다. 없으면 ad-hoc.
IDENTITY="$(security find-identity -v -p codesigning | awk -F'"' '/Apple Development/ {print $2; exit}')"
codesign --force --sign "${IDENTITY:--}" "$APP"
echo "서명: ${IDENTITY:-ad-hoc}"
echo "완료: $APP"
