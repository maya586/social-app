#!/bin/bash
set -e

echo "========================================"
echo "社交应用 Android 客户端打包脚本"
echo "========================================"
echo

# 配置
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CLIENT_DIR="$PROJECT_DIR/client"
OUTPUT_DIR="$PROJECT_DIR/release/android"
KEYSTORE_FILE="$CLIENT_DIR/android/upload-keystore.jks"
KEYSTORE_PROPERTIES="$CLIENT_DIR/android/key.properties"

# 检查 Flutter
if ! command -v flutter &> /dev/null; then
    echo "[错误] Flutter 未安装或不在 PATH 中"
    exit 1
fi

echo "[1/6] 清理旧的构建文件..."
rm -rf "$CLIENT_DIR/build/app"
rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"

cd "$CLIENT_DIR"

echo "[2/6] 获取依赖..."
flutter pub get

echo "[3/6] 检查签名配置..."
if [ ! -f "$KEYSTORE_FILE" ]; then
    echo "[警告] 未找到签名密钥，将构建未签名版本"
    echo "如需签名，请运行: keytool -genkey -v -keystore $KEYSTORE_FILE -keyalg RSA -keysize 2048 -validity 10000 -alias upload"
else
    echo "找到签名密钥"
fi

echo "[4/6] 构建 APK..."
flutter build apk --release

echo "[5/6] 构建 App Bundle..."
flutter build appbundle --release

echo "[6/6] 复制输出文件..."
cp "$CLIENT_DIR/build/app/outputs/flutter-apk/app-release.apk" "$OUTPUT_DIR/SocialApp.apk"
cp "$CLIENT_DIR/build/app/outputs/bundle/release/app-release.aab" "$OUTPUT_DIR/SocialApp.aab"

# 创建版本信息
cat > "$OUTPUT_DIR/version.txt" << EOF
应用名称: 社交应用
版本: 1.0.0
构建时间: $(date)
构建类型: Release
签名状态: $([ -f "$KEYSTORE_FILE" ] && echo "已签名" || echo "未签名")
EOF

echo
echo "========================================"
echo "构建完成!"
echo "输出目录: $OUTPUT_DIR"
echo "  - SocialApp.apk"
echo "  - SocialApp.aab"
echo "========================================"