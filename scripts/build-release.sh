#!/bin/bash
set -euo pipefail

# Gotoo 本地打包脚本
# 用法: ./scripts/build-release.sh [版本号]
# 示例: ./scripts/build-release.sh 0.8.0

VERSION="${1:-0.8.0}"
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$PROJECT_DIR/build"
DIST_DIR="$PROJECT_DIR/dist"
DMG_NAME="Gotoo-${VERSION}"

echo "==> 构建 Gotoo v${VERSION} Release..."

# 清理
rm -rf "$BUILD_DIR" "$DIST_DIR"
mkdir -p "$DIST_DIR"

# Release 构建
cd "$PROJECT_DIR"
xcodebuild -project gotoo.xcodeproj \
  -scheme gotoo \
  -destination 'platform=macOS' \
  -configuration Release \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO \
  SYMROOT="$BUILD_DIR" \
  clean build \
  2>&1 | tail -3

# 验证构建产物
APP_PATH="$BUILD_DIR/Release/gotoo.app"
if [ ! -d "$APP_PATH" ]; then
  echo "错误: 找不到 $APP_PATH"
  exit 1
fi

# 清理调试文件和扩展属性
rm -f "$APP_PATH/Contents/MacOS/__preview.dylib" 2>/dev/null || true
rm -f "$APP_PATH/Contents/MacOS/gotoo.debug.dylib" 2>/dev/null || true
xattr -cr "$APP_PATH"

# Ad-hoc 签名
echo "==> 签名..."
codesign --force --deep --sign - "$APP_PATH"

# 信息
echo "    大小: $(du -sh "$APP_PATH" | cut -f1)"

# 创建 DMG
echo "==> 创建 DMG..."
hdiutil create \
  -volname "Gotoo" \
  -srcfolder "$APP_PATH" \
  -ov \
  -format UDZO \
  "$DIST_DIR/${DMG_NAME}.dmg"

# SHA256
cd "$DIST_DIR"
shasum -a 256 "${DMG_NAME}.dmg" > "${DMG_NAME}.dmg.sha256"

echo ""
echo "==> 完成!"
echo "    DMG:  $DIST_DIR/${DMG_NAME}.dmg ($(du -sh "${DMG_NAME}.dmg" | cut -f1))"
echo "    SHA:  $(cat ${DMG_NAME}.dmg.sha256)"
echo ""
echo "    发布:"
echo "      git add -A && git commit -m 'v${VERSION}'"
echo "      git tag v${VERSION}"
echo "      git push origin main --tags"
