#!/bin/bash
set -e

echo "========================================"
echo "社交应用 iOS 客户端打包脚本"
echo "========================================"
echo

# 配置
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CLIENT_DIR="$PROJECT_DIR/client"
OUTPUT_DIR="$PROJECT_DIR/release/ios"

# 检查系统
if [[ "$OSTYPE" != "darwin"* ]]; then
    echo "[错误] iOS 构建必须在 macOS 上进行"
    exit 1
fi

# 检查 Flutter
if ! command -v flutter &> /dev/null; then
    echo "[错误] Flutter 未安装或不在 PATH 中"
    exit 1
fi

# 检查 Xcode
if ! command -v xcodebuild &> /dev/null; then
    echo "[错误] Xcode 未安装"
    exit 1
fi

echo "[1/5] 清理旧的构建文件..."
rm -rf "$CLIENT_DIR/build/ios"
rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"

cd "$CLIENT_DIR"

echo "[2/5] 获取依赖..."
flutter pub get

echo "[3/5] 安装 CocoaPods 依赖..."
cd ios
pod install
cd ..

echo "[4/5] 构建 iOS (无签名)..."
flutter build ios --release --no-codesign

echo "[5/5] 创建 IPA..."
cd build/ios/iphoneos
mkdir -p Payload
mv Runner.app Payload/
zip -r "$OUTPUT_DIR/SocialApp.ipa" Payload

# 创建版本信息
cat > "$OUTPUT_DIR/version.txt" << EOF
应用名称: 社交应用
版本: 1.0.0
构建时间: $(date)
构建类型: Release (无签名)
注意: 此版本需要使用 Apple Developer 账号签名后才能安装到设备
EOF

echo
echo "========================================"
echo "构建完成!"
echo "输出目录: $OUTPUT_DIR"
echo "  - SocialApp.ipa"
echo "========================================"
echo
echo "后续步骤:"
echo "1. 使用 Xcode 打开 ios/Runner.xcworkspace"
echo "2. 配置 Signing & Capabilities"
echo "3. Product -> Archive -> Distribute App"