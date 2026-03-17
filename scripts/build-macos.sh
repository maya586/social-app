#!/bin/bash
set -e

echo "========================================"
echo "社交应用 macOS 客户端打包脚本"
echo "========================================"
echo

# 配置
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CLIENT_DIR="$PROJECT_DIR/client"
OUTPUT_DIR="$PROJECT_DIR/release/macos"
APP_NAME="SocialApp"

# 检查系统
if [[ "$OSTYPE" != "darwin"* ]]; then
    echo "[错误] macOS 构建必须在 macOS 上进行"
    exit 1
fi

# 检查 Flutter
if ! command -v flutter &> /dev/null; then
    echo "[错误] Flutter 未安装或不在 PATH 中"
    exit 1
fi

echo "[1/5] 清理旧的构建文件..."
rm -rf "$CLIENT_DIR/build/macos"
rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"

cd "$CLIENT_DIR"

echo "[2/5] 获取依赖..."
flutter pub get

echo "[3/5] 构建 macOS..."
flutter build macos --release

echo "[4/5] 复制应用..."
cp -r "$CLIENT_DIR/build/macos/Build/Products/Release/social_app.app" "$OUTPUT_DIR/$APP_NAME.app"

echo "[5/5] 创建 DMG..."
cd "$OUTPUT_DIR"

# 使用 hdiutil 创建 DMG
hdiutil create -volname "$APP_NAME" \
    -srcfolder "$APP_NAME.app" \
    -ov -format UDZO \
    "$APP_NAME.dmg"

# 创建版本信息
cat > "$OUTPUT_DIR/version.txt" << EOF
应用名称: 社交应用
版本: 1.0.0
构建时间: $(date)
构建类型: Release
最低系统要求: macOS 11.0+
EOF

echo
echo "========================================"
echo "构建完成!"
echo "输出目录: $OUTPUT_DIR"
echo "  - $APP_NAME.app"
echo "  - $APP_NAME.dmg"
echo "========================================"