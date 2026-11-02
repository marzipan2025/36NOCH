#!/bin/bash
#
# make_dmg.sh
# build-app.sh 로 앱을 만들고, 배경 이미지가 들어간 배포용 DMG(build/36NOCH-<버전>.dmg)를 만든다.
# 창 레이아웃은 16PNBP/Packaging/make_dmg.sh 를 참고.
#
set -e

APP_NAME="36NOCH"
VOL_NAME="36NOCH"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
BG_IMG="$SCRIPT_DIR/DMGWALL_36NOCH.png"

# 1. 앱 빌드
cd "$PROJECT_DIR"
./build-app.sh
APP_PATH="$PROJECT_DIR/build/${APP_NAME}.app"
VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$APP_PATH/Contents/Info.plist")
OUTPUT="$PROJECT_DIR/build/${APP_NAME}-${VERSION}.dmg"

# 2. 스테이징 디렉터리 준비
TEMP_DIR=$(mktemp -d)
DMG_TEMP="$TEMP_DIR/dmg_temp"
mkdir -p "$DMG_TEMP/.background"
cp -R "$APP_PATH" "$DMG_TEMP/${APP_NAME}.app"
ln -s /Applications "$DMG_TEMP/Applications"
cp "$BG_IMG" "$DMG_TEMP/.background/background.png"

# 3. 이전 마운트 정리
if [ -d "/Volumes/$VOL_NAME" ]; then
    hdiutil detach "/Volumes/$VOL_NAME" -force >/dev/null 2>&1 || \
        diskutil unmount force "/Volumes/$VOL_NAME" >/dev/null 2>&1 || true
fi

# 4. HFS+ RW 이미지 생성 (APFS 에서는 창 속성 설정이 불안정함)
rm -f "$OUTPUT"
hdiutil create -volname "$VOL_NAME" -srcfolder "$DMG_TEMP" -fs HFS+ -format UDRW -ov "$TEMP_DIR/temp.dmg" >/dev/null

# 5. 마운트 후 Finder 로 창 꾸미기
#    배경: 1280x960 (@2x → 640x480 창). 화살표(가운데, y=242) 양 끝에 아이콘 배치.
MOUNT_DIR=$(hdiutil attach "$TEMP_DIR/temp.dmg" | grep "/Volumes/" | awk '{print $3}')

osascript <<APPLESCRIPT
tell application "Finder"
    tell disk "$VOL_NAME"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set bounds of container window to {100, 100, 740, 580}
        set theViewOptions to icon view options of container window
        set arrangement of theViewOptions to not arranged
        set icon size of theViewOptions to 80
        set background picture of theViewOptions to file ".background:background.png"
        set position of item "${APP_NAME}.app" of container window to {175, 243}
        set position of item "Applications" of container window to {465, 243}
        close
        open
        update without registering applications
        delay 1
        close
    end tell
end tell
APPLESCRIPT

# 6. 언마운트 (재시도 후 강제)
sync
sleep 2
for attempt in 1 2 3; do
    hdiutil detach "$MOUNT_DIR" >/dev/null 2>&1 && break
    sleep 1
done
[ -d "$MOUNT_DIR" ] && hdiutil detach "$MOUNT_DIR" -force >/dev/null 2>&1
for i in 1 2 3 4 5; do
    [ ! -d "$MOUNT_DIR" ] && break
    sleep 1
done

# 7. 압축 읽기전용 DMG 로 변환
hdiutil convert "$TEMP_DIR/temp.dmg" -format UDZO -o "$OUTPUT" >/dev/null
rm -rf "$TEMP_DIR"

echo "완료: $OUTPUT ($(du -h "$OUTPUT" | awk '{print $1}'))"
