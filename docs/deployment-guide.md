# 社交应用完整部署方案

## 目录

1. [系统架构](#系统架构)
2. [服务器部署](#服务器部署)
3. [客户端打包部署](#客户端打包部署)
4. [网络配置](#网络配置)
5. [运维监控](#运维监控)

---

## 系统架构

```
┌─────────────────────────────────────────────────────────────────┐
│                         客户端层                                  │
├──────────┬──────────┬──────────┬──────────┬──────────┬─────────┤
│ Windows  │ Android  │   iOS    │  macOS   │  Linux   │   Web   │
└────┬─────┴────┬─────┴────┬─────┴────┬─────┴────┬─────┴────┬────┘
     │          │          │          │          │          │
     └──────────┴──────────┴──────────┴──────────┴──────────┘
                              │
                    ┌─────────▼─────────┐
                    │   Nginx (反向代理)  │
                    │   - SSL终结        │
                    │   - 负载均衡        │
                    └─────────┬─────────┘
                              │
     ┌────────────────────────┼────────────────────────┐
     │                        │                        │
┌────▼────┐            ┌─────▼─────┐           ┌──────▼──────┐
│  API    │            │  WebSocket │           │   静态资源   │
│ :8080   │            │   :8080    │           │   (Web)     │
└────┬────┘            └─────┬─────┘           └─────────────┘
     │                       │
     └───────────┬───────────┘
                 │
┌────────────────▼────────────────┐
│         Go Server (单实例)        │
│  - REST API                      │
│  - WebSocket                     │
│  - WebRTC Signaling              │
└────────────────┬────────────────┘
                 │
     ┌───────────┼───────────┬─────────────┐
     │           │           │             │
┌────▼────┐ ┌────▼────┐ ┌────▼─────┐ ┌─────▼─────┐
│PostgreSQL│ │  Redis  │ │  MinIO   │ │   NATS    │
│  :5432  │ │  :6379  │ │ :9000-01 │ │  :4222   │
└─────────┘ └─────────┘ └──────────┘ └───────────┘
```

---

## 服务器部署

### 方案一：Docker Compose 部署（推荐）

#### 1. 系统要求

| 组件 | 最低配置 | 推荐配置 |
|------|---------|---------|
| CPU | 2核 | 4核+ |
| 内存 | 4GB | 8GB+ |
| 磁盘 | 50GB | 100GB+ SSD |
| 系统 | Ubuntu 20.04+ / CentOS 8+ | Ubuntu 22.04 LTS |

#### 2. 安装 Docker

```bash
# Ubuntu
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER

# 安装 Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# 验证安装
docker --version
docker-compose --version
```

#### 3. 获取代码

```bash
git clone https://github.com/maya586/social-app.git
cd social-app
```

#### 4. 配置环境变量

```bash
cd deploy
cp .env.example .env
nano .env
```

`.env` 配置内容：

```ini
# 数据库配置
POSTGRES_USER=social_user
POSTGRES_PASSWORD=your_secure_password_here
POSTGRES_DB=social_app

# Redis配置
REDIS_PASSWORD=your_redis_password_here

# JWT配置
JWT_SECRET=your_jwt_secret_key_at_least_32_characters
JWT_EXPIRE=7200

# MinIO配置
MINIO_ROOT_USER=admin
MINIO_ROOT_PASSWORD=your_minio_password_here

# 服务配置
SERVER_PORT=8080
GIN_MODE=release

# CORS配置（生产环境修改为实际域名）
CORS_ALLOWED_ORIGINS=https://yourdomain.com,https://app.yourdomain.com
```

#### 5. 启动服务

```bash
# 启动所有服务
docker-compose up -d

# 查看服务状态
docker-compose ps

# 查看日志
docker-compose logs -f server
```

#### 6. 验证部署

```bash
# 检查健康状态
curl http://localhost:8080/health

# 预期返回
{"status":"ok"}

# 检查API文档
# 访问 http://your-server-ip:8080/swagger/index.html
```

### 方案二：手动部署

#### 1. 安装依赖服务

```bash
# PostgreSQL 15
sudo apt install postgresql postgresql-contrib

# Redis 7
sudo apt install redis-server

# MinIO
wget https://dl.min.io/server/minio/release/linux-amd64/minio
sudo chmod +x minio
sudo mv minio /usr/local/bin/
```

#### 2. 配置 PostgreSQL

```bash
sudo -u postgres psql

CREATE USER social_user WITH PASSWORD 'your_password';
CREATE DATABASE social_app OWNER social_user;
GRANT ALL PRIVILEGES ON DATABASE social_app TO social_user;
\q
```

#### 3. 配置 Redis

```bash
sudo nano /etc/redis/redis.conf

# 修改以下配置
bind 127.0.0.1
requirepass your_redis_password
maxmemory 256mb
maxmemory-policy allkeys-lru

sudo systemctl restart redis
```

#### 4. 部署 Go 服务

```bash
# 安装 Go 1.21+
wget https://go.dev/dl/go1.21.6.linux-amd64.tar.gz
sudo tar -C /usr/local -xzf go1.21.6.linux-amd64.tar.gz
export PATH=$PATH:/usr/local/go/bin

# 编译服务
cd server
go mod tidy
CGO_ENABLED=0 GOOS=linux go build -o social-server ./cmd/server

# 创建 systemd 服务
sudo nano /etc/systemd/system/social-server.service
```

`social-server.service` 内容：

```ini
[Unit]
Description=Social App Server
After=network.target postgresql.service redis.service

[Service]
Type=simple
User=www-data
Group=www-data
WorkingDirectory=/opt/social-app
ExecStart=/opt/social-app/social-server
Restart=on-failure
RestartSec=5s

[Install]
WantedBy=multi-user.target
```

```bash
# 启动服务
sudo systemctl daemon-reload
sudo systemctl enable social-server
sudo systemctl start social-server
```

---

## 客户端打包部署

### Windows 客户端

#### 1. 环境准备

```powershell
# 安装 Flutter (Windows)
# 下载: https://docs.flutter.dev/get-started/install/windows

# 或使用 Chocolatey
choco install flutter

# 安装 Visual Studio 2022 (包含 C++ 桌面开发)
choco install visualstudio2022community

# 验证环境
flutter doctor
```

#### 2. 配置应用

修改 `client/lib/core/network/api_config.dart`:

```dart
class ApiConfig {
  static const String baseUrl = 'https://yourdomain.com/api/v1';
  static const String wsUrl = 'wss://yourdomain.com/ws';
}
```

#### 3. 打包命令

```bash
cd client

# 获取依赖
flutter pub get

# 构建 Windows Release 版本
flutter build windows --release

# 输出位置
# client/build/windows/x64/runner/Release/
```

#### 4. 创建安装包

使用 Inno Setup 创建安装程序：

```ini
; setup.iss
[Setup]
AppName=社交应用
AppVersion=1.0.0
DefaultDirName={pf}\SocialApp
DefaultGroupName=社交应用
OutputDir=.\output
OutputBaseFilename=SocialApp-Setup
Compression=lzma2
SolidCompression=yes

[Files]
Source: "build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs

[Icons]
Name: "{group}\社交应用"; Filename: "{app}\client.exe"
Name: "{commondesktop}\社交应用"; Filename: "{app}\client.exe"

[Run]
Filename: "{app}\client.exe"; Description: "启动应用"; Flags: nowait postinstall skipifsilent
```

### Android 客户端

#### 1. 环境准备

```bash
# 安装 JDK 17
sudo apt install openjdk-17-jdk

# 或 macOS
brew install openjdk@17

# 安装 Android SDK
# 下载: https://developer.android.com/studio
# 或使用命令行工具
```

#### 2. 配置签名

创建 `client/android/key.properties`:

```properties
storePassword=your_keystore_password
keyPassword=your_key_password
keyAlias=upload
storeFile=../upload-keystore.jks
```

生成签名密钥：

```bash
keytool -genkey -v -keystore upload-keystore.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias upload
```

#### 3. 修改构建配置

编辑 `client/android/app/build.gradle`:

```gradle
android {
    defaultConfig {
        applicationId "com.social.app"
        minSdkVersion 21
        targetSdkVersion 34
        versionCode 1
        versionName "1.0.0"
    }
    
    signingConfigs {
        release {
            keyAlias keystoreProperties['keyAlias']
            keyPassword keystoreProperties['keyPassword']
            storeFile file(keystoreProperties['storeFile'])
            storePassword keystoreProperties['storePassword']
        }
    }
    
    buildTypes {
        release {
            signingConfig signingConfigs.release
            minifyEnabled true
            shrinkResources true
            proguardFiles getDefaultProguardFile('proguard-android.txt'), 'proguard-rules.pro'
        }
    }
}
```

#### 4. 打包命令

```bash
cd client

# 构建 APK
flutter build apk --release

# 构建 App Bundle (用于 Google Play)
flutter build appbundle --release

# 输出位置
# APK: client/build/app/outputs/flutter-apk/app-release.apk
# AAB: client/build/app/outputs/bundle/release/app-release.aab
```

### iOS 客户端

#### 1. 环境准备

```bash
# 需要 macOS 系统
# 安装 Xcode 15+
# 安装 Flutter

# 安装 CocoaPods
sudo gem install cocoapods
```

#### 2. 配置 Xcode

```bash
cd client/ios

# 安装依赖
pod install

# 打开 Xcode workspace
open Runner.xcworkspace
```

在 Xcode 中配置：
1. 选择 Runner target
2. 设置 Bundle Identifier
3. 配置 Signing & Capabilities
4. 添加 Push Notifications 能力

#### 3. 打包命令

```bash
# 构建 iOS (需要开发者账号)
flutter build ios --release

# 或使用 Xcode 归档
# Product -> Archive -> Distribute App
```

### macOS 客户端

#### 1. 环境准备

```bash
# macOS 系统
# Xcode 15+
# Flutter SDK

# 启用 macOS 桌面支持
flutter config --enable-macos-desktop
```

#### 2. 打包命令

```bash
cd client

# 构建 macOS
flutter build macos --release

# 创建 DMG
cd build/macos/Build/Products/Release
hdiutil create -volname "社交应用" \
  -srcfolder social_app.app \
  -ov -format UDZO \
  SocialApp-macos.dmg
```

### Linux 客户端

#### 1. 环境准备

```bash
# Ubuntu/Debian
sudo apt install clang cmake ninja-build pkg-config \
  libgtk-3-dev liblzma-dev libstdc++-12-dev \
  libpulse-dev libmpv-dev

# 启用 Linux 桌面支持
flutter config --enable-linux-desktop
```

#### 2. 打包命令

```bash
cd client

# 构建 Linux
flutter build linux --release

# 创建 tarball
cd build/linux/x64/release/bundle
tar -czvf social-app-linux-x64.tar.gz *
```

#### 3. 创建 .deb 包

创建 `packaging/debian/control`:

```
Package: social-app
Version: 1.0.0
Section: net
Priority: optional
Architecture: amd64
Maintainer: Your Name <your@email.com>
Description: 跨平台社交应用
 一款简洁高效的跨平台社交应用，支持即时通讯和音视频通话。
Depends: libgtk-3-0, libpulse0, libmpv2
```

```bash
# 构建 deb 包
mkdir -p packaging/debian/usr/bin
cp -r build/linux/x64/release/bundle/* packaging/debian/usr/share/social-app/
dpkg-deb --build packaging/debian social-app_1.0.0_amd64.deb
```

### Web 客户端

#### 1. 构建

```bash
cd client

# 构建 Web 版本
flutter build web --release

# 输出位置
# client/build/web/
```

#### 2. 部署到 CDN/Nginx

```nginx
# /etc/nginx/sites-available/social-app-web
server {
    listen 443 ssl http2;
    server_name app.yourdomain.com;

    ssl_certificate /etc/letsencrypt/live/yourdomain.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/yourdomain.com/privkey.pem;

    root /var/www/social-app-web;
    index index.html;

    location / {
        try_files $uri $uri/ /index.html;
    }

    # 缓存静态资源
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
}

server {
    listen 80;
    server_name app.yourdomain.com;
    return 301 https://$server_name$request_uri;
}
```

```bash
# 部署
sudo mkdir -p /var/www/social-app-web
sudo cp -r build/web/* /var/www/social-app-web/
sudo chown -R www-data:www-data /var/www/social-app-web
```

---

## 网络配置

### Nginx 反向代理配置

```nginx
# /etc/nginx/sites-available/social-app
upstream backend {
    server 127.0.0.1:8080;
    keepalive 32;
}

# HTTP 重定向到 HTTPS
server {
    listen 80;
    server_name yourdomain.com api.yourdomain.com;
    return 301 https://$server_name$request_uri;
}

# HTTPS 主配置
server {
    listen 443 ssl http2;
    server_name yourdomain.com api.yourdomain.com;

    # SSL 配置
    ssl_certificate /etc/letsencrypt/live/yourdomain.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/yourdomain.com/privkey.pem;
    ssl_session_timeout 1d;
    ssl_session_cache shared:SSL:50m;
    ssl_session_tickets off;

    # 现代加密套件
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256;
    ssl_prefer_server_ciphers off;

    # HSTS
    add_header Strict-Transport-Security "max-age=63072000" always;

    # API 代理
    location /api/ {
        proxy_pass http://backend;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        # 速率限制
        limit_req zone=api burst=20 nodelay;
    }

    # WebSocket 代理
    location /ws {
        proxy_pass http://backend;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_read_timeout 3600s;
        proxy_send_timeout 3600s;
    }

    # MinIO 文件服务
    location /files/ {
        proxy_pass http://127.0.0.1:9000/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }

    # 健康检查
    location /health {
        proxy_pass http://backend;
        access_log off;
    }
}

# 速率限制配置 (http 块)
limit_req_zone $binary_remote_addr zone=api:10m rate=10r/s;
```

### SSL 证书配置

```bash
# 安装 Certbot
sudo apt install certbot python3-certbot-nginx

# 获取证书
sudo certbot --nginx -d yourdomain.com -d api.yourdomain.com

# 自动续期
sudo certbot renew --dry-run
```

### 防火墙配置

```bash
# UFW (Ubuntu)
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow ssh
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw enable

# 或 iptables
iptables -A INPUT -p tcp --dport 22 -j ACCEPT
iptables -A INPUT -p tcp --dport 80 -j ACCEPT
iptables -A INPUT -p tcp --dport 443 -j ACCEPT
iptables -A INPUT -j DROP
```

---

## 运维监控

### 1. 日志管理

```yaml
# docker-compose.yml 添加日志配置
services:
  server:
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"
```

### 2. 健康检查脚本

```bash
#!/bin/bash
# healthcheck.sh

SERVICES=("postgres" "redis" "minio" "server")
ALERT_EMAIL="admin@yourdomain.com"

for service in "${SERVICES[@]}"; do
    if ! docker-compose ps | grep -q "$service.*Up"; then
        echo "Service $service is down!" | mail -s "Alert: $service down" $ALERT_EMAIL
        docker-compose restart $service
    fi
done

# 检查 API 健康状态
if ! curl -sf http://localhost:8080/health > /dev/null; then
    echo "API health check failed!" | mail -s "Alert: API unhealthy" $ALERT_EMAIL
fi
```

### 3. 备份策略

```bash
#!/bin/bash
# backup.sh

BACKUP_DIR="/backup/$(date +%Y%m%d)"
mkdir -p $BACKUP_DIR

# 备份 PostgreSQL
docker-compose exec -T postgres pg_dump -U social_user social_app > $BACKUP_DIR/db.sql

# 备份 Redis
docker-compose exec -T redis redis-cli BGSAVE
cp /var/lib/redis/dump.rdb $BACKUP_DIR/redis.rdb

# 备份 MinIO
mc mirror local/social-app $BACKUP_DIR/minio

# 压缩备份
tar -czvf $BACKUP_DIR.tar.gz $BACKUP_DIR
rm -rf $BACKUP_DIR

# 保留最近 7 天备份
find /backup -name "*.tar.gz" -mtime +7 -delete

# 上传到云存储 (可选)
# aws s3 cp $BACKUP_DIR.tar.gz s3://your-bucket/backups/
```

### 4. 监控配置 (Prometheus + Grafana)

`prometheus.yml`:

```yaml
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'social-app'
    static_configs:
      - targets: ['server:8080']
    metrics_path: '/metrics'
```

添加到 `docker-compose.yml`:

```yaml
  prometheus:
    image: prom/prometheus
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml
    ports:
      - "9090:9090"

  grafana:
    image: grafana/grafana
    ports:
      - "3000:3000"
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=admin
    volumes:
      - grafana-data:/var/lib/grafana
```

---

## 客户端分发

### 下载页面示例

创建 `download.html`:

```html
<!DOCTYPE html>
<html>
<head>
    <title>社交应用下载</title>
    <style>
        body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; max-width: 800px; margin: 50px auto; padding: 20px; }
        .platform { display: flex; align-items: center; padding: 20px; margin: 10px 0; border: 1px solid #ddd; border-radius: 8px; }
        .platform-icon { font-size: 48px; margin-right: 20px; }
        .platform-info { flex: 1; }
        .download-btn { background: #007AFF; color: white; padding: 12px 24px; border-radius: 6px; text-decoration: none; }
        .download-btn:hover { background: #0056b3; }
    </style>
</head>
<body>
    <h1>社交应用下载</h1>
    
    <div class="platform">
        <div class="platform-icon">🪟</div>
        <div class="platform-info">
            <h3>Windows</h3>
            <p>支持 Windows 10/11 (64位)</p>
        </div>
        <a href="/downloads/SocialApp-Setup.exe" class="download-btn">下载</a>
    </div>
    
    <div class="platform">
        <div class="platform-icon">🤖</div>
        <div class="platform-info">
            <h3>Android</h3>
            <p>支持 Android 5.0+</p>
        </div>
        <a href="/downloads/SocialApp.apk" class="download-btn">下载 APK</a>
    </div>
    
    <div class="platform">
        <div class="platform-icon">🍎</div>
        <div class="platform-info">
            <h3>iOS</h3>
            <p>支持 iOS 13.0+</p>
        </div>
        <a href="https://apps.apple.com/app/id123456789" class="download-btn">App Store</a>
    </div>
    
    <div class="platform">
        <div class="platform-icon">🖥️</div>
        <div class="platform-info">
            <h3>macOS</h3>
            <p>支持 macOS 11.0+</p>
        </div>
        <a href="/downloads/SocialApp-macos.dmg" class="download-btn">下载</a>
    </div>
    
    <div class="platform">
        <div class="platform-icon">🐧</div>
        <div class="platform-info">
            <h3>Linux</h3>
            <p>支持 Ubuntu 20.04+</p>
        </div>
        <a href="/downloads/social-app-linux-x64.tar.gz" class="download-btn">下载</a>
    </div>
    
    <div class="platform">
        <div class="platform-icon">🌐</div>
        <div class="platform-info">
            <h3>Web</h3>
            <p>无需安装，浏览器直接使用</p>
        </div>
        <a href="https://app.yourdomain.com" class="download-btn">打开</a>
    </div>
</body>
</html>
```

---

## 故障排查

### 常见问题

1. **数据库连接失败**
   ```bash
   # 检查 PostgreSQL 状态
   docker-compose logs postgres
   
   # 重启数据库
   docker-compose restart postgres
   ```

2. **WebSocket 连接失败**
   - 检查 Nginx WebSocket 代理配置
   - 确认防火墙未阻止 WebSocket 连接

3. **文件上传失败**
   - 检查 MinIO 服务状态
   - 确认存储桶权限配置

4. **推送通知不工作**
   - 检查 FCM/APNs 配置
   - 确认设备 Token 正确注册

---

## 更新部署

```bash
# 拉取最新代码
git pull origin master

# 重新构建并部署
docker-compose build --no-cache
docker-compose up -d

# 数据库迁移（如有）
docker-compose exec server ./migrate
```