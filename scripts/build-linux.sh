#!/bin/bash
set -e

echo "========================================"
echo "社交应用 Linux 客户端打包脚本"
echo "========================================"
echo

# 配置
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CLIENT_DIR="$PROJECT_DIR/client"
OUTPUT_DIR="$PROJECT_DIR/release/linux"

# 检查 Flutter
if ! command -v flutter &> /dev/null; then
    echo "[错误] Flutter 未安装或不在 PATH 中"
    exit 1
fi

echo "[1/5] 检查 Linux 桌面支持..."
flutter config --enable-linux-desktop

echo "[2/5] 清理旧的构建文件..."
rm -rf "$CLIENT_DIR/build/linux"
rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"

cd "$CLIENT_DIR"

echo "[3/5] 获取依赖..."
flutter pub get

echo "[4/5] 构建 Linux..."
flutter build linux --release

echo "[5/5] 创建发布包..."
cd build/linux/x64/release/bundle
tar -czvf "$OUTPUT_DIR/SocialApp-linux-x64.tar.gz" *

# 创建 .deb 包
cd "$OUTPUT_DIR"
mkdir -p social-app/DEBIAN
mkdir -p social-app/usr/share/social-app
mkdir -p social-app/usr/bin

# 复制应用文件
cp -r "$CLIENT_DIR/build/linux/x64/release/bundle/"* social-app/usr/share/social-app/

# 创建启动脚本
cat > social-app/usr/bin/social-app << 'EOF'
#!/bin/bash
cd /usr/share/social-app
./social_app
EOF
chmod +x social-app/usr/bin/social-app

# 创建控制文件
cat > social-app/DEBIAN/control << EOF
Package: social-app
Version: 1.0.0
Section: net
Priority: optional
Architecture: amd64
Maintainer: Social App Team <team@socialapp.com>
Description: 跨平台社交应用
 一款简洁高效的跨平台社交应用，支持即时通讯和音视频通话。
Depends: libgtk-3-0, libpulse0
EOF

# 构建 deb 包
dpkg-deb --build social-app SocialApp_1.0.0_amd64.deb
rm -rf social-app

# 创建版本信息
cat > "$OUTPUT_DIR/version.txt" << EOF
应用名称: 社交应用
版本: 1.0.0
构建时间: $(date)
构建类型: Release
系统要求: Ubuntu 20.04+ / Debian 11+
EOF

echo
echo "========================================"
echo "构建完成!"
echo "输出目录: $OUTPUT_DIR"
echo "  - SocialApp-linux-x64.tar.gz"
echo "  - SocialApp_1.0.0_amd64.deb"
echo "========================================"