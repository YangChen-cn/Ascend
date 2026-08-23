#!/usr/bin/env bash
set -euo pipefail

APP_NAME="知境录"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
ENTITLEMENTS="$ROOT_DIR/Ascend/Support/Ascend.entitlements"
SWIFT_PATH_MAP="-file-prefix-map $ROOT_DIR=AscendBuild"
SIGN_IDENTITY="${ASCEND_SIGN_IDENTITY:-Ascend Local Signing}"
ARCHITECTURES=(arm64)
TEMP_PARENT="${TMPDIR:-/private/tmp}"
TEMP_PARENT="${TEMP_PARENT%/}"
WORK_DIR=""
MOUNT_DIR=""
DMG_ATTACHED=0

source "$ROOT_DIR/script/portable_bundle.sh"

cleanup() {
  if [[ "$DMG_ATTACHED" -eq 1 && -n "$MOUNT_DIR" ]]; then
    /usr/bin/hdiutil detach "$MOUNT_DIR" -quiet || true
  fi
  if [[ -n "$WORK_DIR" && -d "$WORK_DIR" ]]; then
    rm -rf "$WORK_DIR"
  fi
  if [[ -n "$MOUNT_DIR" && -d "$MOUNT_DIR" ]]; then
    rmdir "$MOUNT_DIR" 2>/dev/null || true
  fi
}

trap cleanup EXIT

echo "=== 0. 检查代码签名证书身份: $SIGN_IDENTITY ==="
check_signing_identity "$SIGN_IDENTITY"

cd "$ROOT_DIR"
echo "=== 1. 重新生成 Xcode 工程 ==="
xcodegen generate
mkdir -p "$DIST_DIR"

# 清理旧产物
find "$DIST_DIR" -maxdepth 1 -type f \( -name "Ascend-*.dmg" -o -name "Ascend-*.sha256" \) -delete
rm -rf "$DIST_DIR/$APP_NAME.app"

VERSION=""
for ARCHITECTURE in "${ARCHITECTURES[@]}"; do
  DERIVED_DATA="$ROOT_DIR/DerivedData/$ARCHITECTURE"
  SOURCE_APP="$DERIVED_DATA/Build/Products/Release/$APP_NAME.app"

  echo "=== 2. 编译 Release 产物 ($ARCHITECTURE) ==="
  xcodebuild \
    -project Ascend.xcodeproj \
    -scheme Ascend \
    -configuration Release \
    -destination "generic/platform=macOS" \
    -derivedDataPath "$DERIVED_DATA" \
    ARCHS="$ARCHITECTURE" \
    VALID_ARCHS="$ARCHITECTURE" \
    CLANG_COVERAGE_MAPPING=NO \
    CODE_SIGNING_ALLOWED=NO \
    DEBUG_INFORMATION_FORMAT=dwarf \
    ENABLE_CODE_COVERAGE=NO \
    ENABLE_DEBUG_DYLIB=NO \
    ONLY_ACTIVE_ARCH=NO \
    "OTHER_SWIFT_FLAGS=$SWIFT_PATH_MAP" \
    clean build

  if [[ -z "$VERSION" ]]; then
    VERSION="$(/usr/bin/plutil -extract CFBundleShortVersionString raw "$SOURCE_APP/Contents/Info.plist")"
  fi

  OUTPUT_DMG="$DIST_DIR/Ascend-v$VERSION-$ARCHITECTURE.dmg"
  WORK_DIR="$(mktemp -d "$TEMP_PARENT/ascend-release-$ARCHITECTURE.XXXXXX")"
  MOUNT_DIR="$(mktemp -d "$TEMP_PARENT/ascend-mount-$ARCHITECTURE.XXXXXX")"
  APP_COPY="$WORK_DIR/$APP_NAME.app"
  DMG_ROOT="$WORK_DIR/image"

  echo "=== 3. 净化构建产物并应用自签名证书 ($SIGN_IDENTITY) ==="
  /usr/bin/ditto "$SOURCE_APP" "$APP_COPY"
  sanitize_portable_bundle "$APP_COPY"
  sign_portable_bundle "$APP_COPY" "$ENTITLEMENTS" "$SIGN_IDENTITY"
  
  echo "=== 4. 验证签名与便携性 ==="
  /usr/bin/codesign --verify --deep --strict --verbose=2 "$APP_COPY"
  verify_portable_bundle "$APP_COPY" "$ROOT_DIR"

  echo "=== 5. 制作与挂载校验 DMG ==="
  mkdir -p "$DMG_ROOT"
  /usr/bin/ditto "$APP_COPY" "$DMG_ROOT/$APP_NAME.app"
  /bin/ln -s /Applications "$DMG_ROOT/Applications"
  /usr/bin/hdiutil create \
    -volname "$APP_NAME" \
    -srcfolder "$DMG_ROOT" \
    -format UDZO \
    -ov \
    "$OUTPUT_DMG"
  /usr/bin/hdiutil verify "$OUTPUT_DMG"
  /usr/bin/hdiutil attach \
    -readonly \
    -nobrowse \
    -mountpoint "$MOUNT_DIR" \
    "$OUTPUT_DMG" >/dev/null
  DMG_ATTACHED=1
  /usr/bin/codesign --verify --deep --strict --verbose=2 "$MOUNT_DIR/$APP_NAME.app"
  verify_portable_bundle "$MOUNT_DIR/$APP_NAME.app" "$ROOT_DIR"
  /usr/bin/hdiutil detach "$MOUNT_DIR" -quiet
  DMG_ATTACHED=0

  echo "=== 6. 计算 SHA256 校验和 ==="
  cd "$DIST_DIR"
  DMG_BASENAME="$(basename "$OUTPUT_DMG")"
  shasum -a 256 "$DMG_BASENAME" > "${DMG_BASENAME}.sha256"

  rm -rf "$WORK_DIR"
  WORK_DIR=""
  rmdir "$MOUNT_DIR" 2>/dev/null || true
  MOUNT_DIR=""

  echo "=========================================="
  echo "🎉 便携式发布镜像生成成功!"
  echo "签名证书: $SIGN_IDENTITY"
  echo "DMG 路径: $OUTPUT_DMG"
  echo "SHA256: $(cat "${DMG_BASENAME}.sha256")"
  echo "=========================================="

  /bin/rm -rf "$DERIVED_DATA"
done
