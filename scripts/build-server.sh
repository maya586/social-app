#!/bin/bash
set -e

echo "========================================"
echo "社交应用服务端打包脚本"
echo "========================================"
echo

# 配置
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SERVER_DIR="$PROJECT_DIR/server"
OUTPUT_DIR="$PROJECT_DIR/release/server"

echo "[1/3] 清理旧的构建文件..."
rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"

cd "$SERVER_DIR"

echo "[2/3] 整理依赖..."
go mod tidy

echo "[3/3] 构建服务端..."

# Linux AMD64
echo "  - 构建 Linux AMD64..."
CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -ldflags="-s -w" -o "$OUTPUT_DIR/server-linux-amd64" ./cmd/server

# Linux ARM64
echo "  - 构建 Linux ARM64..."
CGO_ENABLED=0 GOOS=linux GOARCH=arm64 go build -ldflags="-s -w" -o "$OUTPUT_DIR/server-linux-arm64" ./cmd/server

# Windows AMD64
echo "  - 构建 Windows AMD64..."
CGO_ENABLED=0 GOOS=windows GOARCH=amd64 go build -ldflags="-s -w" -o "$OUTPUT_DIR/server-windows-amd64.exe" ./cmd/server

# macOS AMD64
echo "  - 构建 macOS AMD64..."
CGO_ENABLED=0 GOOS=darwin GOARCH=amd64 go build -ldflags="-s -w" -o "$OUTPUT_DIR/server-darwin-amd64" ./cmd/server

# macOS ARM64 (Apple Silicon)
echo "  - 构建 macOS ARM64..."
CGO_ENABLED=0 GOOS=darwin GOARCH=arm64 go build -ldflags="-s -w" -o "$OUTPUT_DIR/server-darwin-arm64" ./cmd/server

# 复制配置文件
echo "  - 复制配置文件..."
cp -r "$PROJECT_DIR/deploy" "$OUTPUT_DIR/deploy-config"

# 创建版本信息
cat > "$OUTPUT_DIR/version.txt" << EOF
服务名称: 社交应用服务端
版本: 1.0.0
构建时间: $(date)
构建类型: Release

包含文件:
- server-linux-amd64      (Linux x86_64)
- server-linux-arm64      (Linux ARM64)
- server-windows-amd64.exe (Windows x86_64)
- server-darwin-amd64     (macOS Intel)
- server-darwin-arm64     (macOS Apple Silicon)
- deploy-config/          (Docker 部署配置)
EOF

# 创建启动脚本
cat > "$OUTPUT_DIR/start.sh" << 'EOF'
#!/bin/bash
# 社交应用服务端启动脚本

# 设置环境变量
export GIN_MODE=release

# 检查配置
if [ ! -f ".env" ]; then
    echo "错误: .env 配置文件不存在"
    echo "请复制 deploy-config/.env.example 为 .env 并修改配置"
    exit 1
fi

# 启动服务
./server-linux-amd64
EOF
chmod +x "$OUTPUT_DIR/start.sh"

# 创建 Windows 启动脚本
cat > "$OUTPUT_DIR/start.bat" << 'EOF'
@echo off
chcp 65001 >nul
echo 社交应用服务端启动中...
set GIN_MODE=release
server-windows-amd64.exe
pause
EOF

echo
echo "========================================"
echo "构建完成!"
echo "输出目录: $OUTPUT_DIR"
echo ""
ls -lh "$OUTPUT_DIR"
echo "========================================"