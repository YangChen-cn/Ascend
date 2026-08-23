#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

VERSION="0.9.0"
APP_NAME="知境录"
DMG_NAME="Ascend-v${VERSION}-arm64.dmg"
BUILD_DIR="${ROOT_DIR}/.build/ReleaseDerivedData"
OUTPUT_DIR="${ROOT_DIR}/dist"
STAGE_DIR="${ROOT_DIR}/.build/dmg_stage"

echo "=== 1. 重新生成 Xcode 工程 ==="
xcodegen generate

echo "=== 2. 编译 Release 产物 (Apple 芯片 arm64) ==="
rm -rf "$BUILD_DIR"
xcodebuild build \
  -project Ascend.xcodeproj \
  -scheme Ascend \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  ARCHS=arm64 \
  ONLY_ACTIVE_ARCH=NO \
  -derivedDataPath "$BUILD_DIR"

APP_PATH="${BUILD_DIR}/Build/Products/Release/${APP_NAME}.app"
if [ ! -d "$APP_PATH" ]; then
  echo "错误: 未找到编译产物 ${APP_PATH}"
  exit 1
fi

echo "=== 3. 准备 DMG 打包暂存目录 ==="
rm -rf "$STAGE_DIR" "$OUTPUT_DIR"
mkdir -p "$STAGE_DIR" "$OUTPUT_DIR"

cp -R "$APP_PATH" "$STAGE_DIR/"
ln -s /Applications "$STAGE_DIR/Applications"

echo "=== 4. 制作 DMG 磁盘映像 ==="
DMG_PATH="${OUTPUT_DIR}/${DMG_NAME}"
rm -f "$DMG_PATH"

hdiutil create \
  -volname "${APP_NAME}" \
  -srcfolder "$STAGE_DIR" \
  -ov \
  -format UDBZ \
  "$DMG_PATH"

echo "=== 5. 计算 SHA256 校验和 ==="
cd "$OUTPUT_DIR"
shasum -a 256 "$DMG_NAME" > "${DMG_NAME}.sha256"

echo "=========================================="
echo "🎉 打包完成!"
echo "DMG 文件: ${DMG_PATH}"
echo "SHA256: $(cat "${DMG_NAME}.sha256")"
echo "=========================================="
