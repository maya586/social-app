#!/bin/bash
set -e

echo "========================================"
echo "社交应用 Web 客户端打包脚本"
echo "========================================"
echo

# 配置
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CLIENT_DIR="$PROJECT_DIR/client"
OUTPUT_DIR="$PROJECT_DIR/release/web"

# 检查 Flutter
if ! command -v flutter &> /dev/null; then
    echo "[错误] Flutter 未安装或不在 PATH 中"
    exit 1
fi

echo "[1/4] 清理旧的构建文件..."
rm -rf "$CLIENT_DIR/build/web"
rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"

cd "$CLIENT_DIR"

echo "[2/4] 获取依赖..."
flutter pub get

echo "[3/4] 构建 Web..."
flutter build web --release

echo "[4/4] 复制输出文件..."
cp -r "$CLIENT_DIR/build/web/"* "$OUTPUT_DIR/"

# 创建版本信息
cat > "$OUTPUT_DIR/version.txt" << EOF
应用名称: 社交应用
版本: 1.0.0
构建时间: $(date)
构建类型: Release (Web)
部署说明:
1. 将 web 目录内容上传到服务器
2. 配置 Nginx 或其他 Web 服务器
3. 配置 API 代理指向后端服务
EOF

# 创建 Nginx 配置示例
cat > "$OUTPUT_DIR/nginx.conf.example" << 'EOF'
server {
    listen 80;
    server_name app.example.com;
    
    root /var/www/social-app-web;
    index index.html;
    
    # SPA 路由支持
    location / {
        try_files $uri $uri/ /index.html;
    }
    
    # API 代理
    location /api/ {
        proxy_pass http://localhost:8080;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
    
    # WebSocket 代理
    location /ws {
        proxy_pass http://localhost:8080;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }
    
    # 静态资源缓存
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
}
EOF

# 创建压缩包
cd "$PROJECT_DIR/release"
tar -czvf SocialApp-web.tar.gz web/

echo
echo "========================================"
echo "构建完成!"
echo "输出目录: $OUTPUT_DIR"
echo "  - index.html 及其他静态文件"
echo "  - nginx.conf.example (Nginx 配置示例)"
echo "========================================"