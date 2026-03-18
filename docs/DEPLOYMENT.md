# 社交应用服务端部署方案

## 目录

- [1. 系统架构](#1-系统架构)
- [2. 环境要求](#2-环境要求)
- [3. 目录结构](#3-目录结构)
- [4. 快速部署](#4-快速部署)
- [5. 配置说明](#5-配置说明)
- [6. 服务管理](#6-服务管理)
- [7. 数据备份](#7-数据备份)
- [8. 监控告警](#8-监控告警)
- [9. 故障排查](#9-故障排查)
- [10. 安全加固](#10-安全加固)
- [11. 性能优化](#11-性能优化)
- [12. 升级指南](#12-升级指南)

---

## 1. 系统架构

### 1.1 架构图

```
                    ┌─────────────────────────────────────────────────────────┐
                    │                      Nginx (反向代理)                    │
                    │                    端口: 80/443 (SSL)                   │
                    └─────────────────────────────────────────────────────────┘
                                              │
                    ┌─────────────────────────┴─────────────────────────┐
                    │                                                   │
                    ▼                                                   ▼
        ┌───────────────────┐                             ┌───────────────────┐
        │   WebSocket 服务   │                             │    API 服务       │
        │   端口: 8080       │                             │    端口: 8080     │
        │  (实时通讯/通话)    │                             │   (REST API)      │
        └───────────────────┘                             └───────────────────┘
                    │                                                   │
                    └─────────────────────────┬─────────────────────────┘
                                              │
        ┌─────────────────────────────────────┼─────────────────────────────────────┐
        │                                     │                                     │
        ▼                                     ▼                                     ▼
┌───────────────────┐             ┌───────────────────┐             ┌───────────────────┐
│    PostgreSQL     │             │      Redis        │             │      MinIO        │
│   端口: 5432      │             │    端口: 6379     │             │   端口: 9000/9001 │
│   (主数据库)       │             │   (缓存/会话)      │             │   (对象存储)       │
└───────────────────┘             └───────────────────┘             └───────────────────┘
```

### 1.2 组件说明

| 组件 | 版本 | 用途 | 端口 |
|------|------|------|------|
| Server | Go 1.21+ | 主服务（API + WebSocket） | 8080 |
| PostgreSQL | 15-alpine | 主数据库 | 5432 |
| Redis | 7-alpine | 缓存、会话、在线状态 | 6379 |
| MinIO | latest | 对象存储（图片、文件） | 9000/9001 |
| Nginx | latest | 反向代理、SSL、负载均衡 | 80/443 |

---

## 2. 环境要求

### 2.1 硬件要求

| 环境 | CPU | 内存 | 磁盘 | 网络 |
|------|-----|------|------|------|
| 开发/测试 | 2核 | 4GB | 50GB SSD | 10Mbps |
| 生产环境（小型） | 4核 | 8GB | 200GB SSD | 100Mbps |
| 生产环境（中型） | 8核 | 16GB | 500GB SSD | 500Mbps |
| 生产环境（大型） | 16核+ | 32GB+ | 1TB+ SSD | 1Gbps+ |

### 2.2 软件要求

- 操作系统：Ubuntu 22.04 LTS / CentOS 8+ / Debian 11+
- Docker：24.0+
- Docker Compose：2.20+
- Git：2.30+

### 2.3 安装 Docker

```bash
# Ubuntu/Debian
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER

# 安装 Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/download/v2.23.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# 验证安装
docker --version
docker-compose --version
```

---

## 3. 目录结构

```
/opt/social-app/
├── docker-compose.yml          # Docker Compose 主配置
├── .env                        # 环境变量配置
├── nginx/
│   ├── nginx.conf             # Nginx 主配置
│   ├── conf.d/
│   │   └── default.conf       # 站点配置
│   └── ssl/                   # SSL 证书目录
│       ├── cert.pem
│       └── key.pem
├── server/                    # 服务端代码
│   ├── Dockerfile
│   ├── cmd/
│   ├── internal/
│   └── go.mod
├── init-db/                   # 数据库初始化脚本
│   └── 01-init.sql
├── scripts/                   # 运维脚本
│   ├── backup.sh              # 备份脚本
│   ├── restore.sh             # 恢复脚本
│   ├── health-check.sh        # 健康检查
│   └── deploy.sh              # 部署脚本
├── monitoring/                # 监控配置
│   ├── prometheus.yml
│   └── alertmanager.yml
└── logs/                      # 日志目录
    ├── server/
    ├── nginx/
    └── postgres/
```

---

## 4. 快速部署

### 4.1 克隆代码

```bash
# 创建目录
sudo mkdir -p /opt/social-app
sudo chown $USER:$USER /opt/social-app
cd /opt/social-app

# 克隆代码
git clone https://github.com/your-org/social-app.git .
```

### 4.2 配置环境变量

```bash
# 复制示例配置
cp .env.example .env

# 编辑配置
vim .env
```

### 4.3 启动服务

```bash
# 启动所有服务
docker-compose up -d

# 查看服务状态
docker-compose ps

# 查看日志
docker-compose logs -f server
```

### 4.4 验证部署

```bash
# 检查服务健康状态
curl http://localhost:8080/health

# 检查数据库连接
docker-compose exec postgres pg_isready -U postgres

# 检查 Redis 连接
docker-compose exec redis redis-cli ping
```

---

## 5. 配置说明

### 5.1 环境变量 (.env)

```bash
# ==================== 服务器配置 ====================
SERVER_PORT=8080
SERVER_READ_TIMEOUT=10
SERVER_WRITE_TIMEOUT=10
GIN_MODE=release

# ==================== 数据库配置 ====================
DB_HOST=postgres
DB_PORT=5432
DB_USER=postgres
DB_PASSWORD=your_secure_password_here
DB_NAME=social_app
DB_SSLMODE=disable
DB_MAX_OPEN_CONNS=100
DB_MAX_IDLE_CONNS=10
DB_CONN_MAX_LIFETIME=3600

# ==================== Redis配置 ====================
REDIS_ADDR=redis:6379
REDIS_PASSWORD=
REDIS_DB=0

# ==================== JWT配置 ====================
JWT_SECRET=your_jwt_secret_key_at_least_32_characters_long_for_security
JWT_EXPIRE_SECONDS=7200
JWT_REFRESH_EXPIRE_SECONDS=604800

# ==================== MinIO配置 ====================
MINIO_ENDPOINT=minio:9000
MINIO_ACCESS_KEY=minioadmin
MINIO_SECRET_KEY=your_minio_secret_key_here
MINIO_BUCKET=social-app
MINIO_USE_SSL=false

# ==================== WebRTC配置 ====================
STUN_URLS=stun:stun.l.google.com:19302,stun:stun1.l.google.com:19302
TURN_URL=
TURN_USERNAME=
TURN_PASSWORD=

# ==================== 日志配置 ====================
LOG_LEVEL=info
LOG_FORMAT=json
LOG_OUTPUT=/var/log/social-app/server.log

# ==================== CORS配置 ====================
CORS_ALLOWED_ORIGINS=https://yourdomain.com,https://app.yourdomain.com
CORS_ALLOWED_METHODS=GET,POST,PUT,DELETE,OPTIONS
CORS_ALLOWED_HEADERS=Content-Type,Authorization,X-Requested-With

# ==================== 限流配置 ====================
RATE_LIMIT_REQUESTS=100
RATE_LIMIT_DURATION=60

# ==================== 文件上传配置 ====================
MAX_UPLOAD_SIZE=10485760
ALLOWED_FILE_TYPES=image/jpeg,image/png,image/gif,video/mp4

# ==================== Firebase配置 (可选) ====================
FIREBASE_CREDENTIALS_FILE=/app/firebase-credentials.json
```

### 5.2 Docker Compose 配置

```yaml
version: '3.8'

services:
  # ==================== 主服务 ====================
  server:
    build:
      context: ./server
      dockerfile: Dockerfile
    container_name: social-app-server
    restart: unless-stopped
    ports:
      - "8080:8080"
    environment:
      - GIN_MODE=${GIN_MODE:-release}
    env_file:
      - .env
    depends_on:
      postgres:
        condition: service_healthy
      redis:
        condition: service_healthy
      minio:
        condition: service_healthy
    networks:
      - social-app-network
    volumes:
      - ./logs/server:/var/log/social-app
      - ./firebase-credentials.json:/app/firebase-credentials.json:ro
    healthcheck:
      test: ["CMD", "wget", "-q", "--spider", "http://localhost:8080/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s
    deploy:
      resources:
        limits:
          cpus: '2'
          memory: 2G
        reservations:
          cpus: '0.5'
          memory: 512M
    logging:
      driver: "json-file"
      options:
        max-size: "100m"
        max-file: "5"

  # ==================== 数据库 ====================
  postgres:
    image: postgres:15-alpine
    container_name: social-app-postgres
    restart: unless-stopped
    ports:
      - "5432:5432"
    environment:
      POSTGRES_USER: ${DB_USER:-postgres}
      POSTGRES_PASSWORD: ${DB_PASSWORD:-postgres}
      POSTGRES_DB: ${DB_NAME:-social_app}
      PGDATA: /var/lib/postgresql/data/pgdata
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./init-db:/docker-entrypoint-initdb.d:ro
    networks:
      - social-app-network
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${DB_USER:-postgres} -d ${DB_NAME:-social_app}"]
      interval: 10s
      timeout: 5s
      retries: 5
      start_period: 30s
    deploy:
      resources:
        limits:
          cpus: '2'
          memory: 2G
        reservations:
          cpus: '0.5'
          memory: 512M
    logging:
      driver: "json-file"
      options:
        max-size: "50m"
        max-file: "3"

  # ==================== 缓存 ====================
  redis:
    image: redis:7-alpine
    container_name: social-app-redis
    restart: unless-stopped
    ports:
      - "6379:6379"
    command: >
      redis-server
      --appendonly yes
      --maxmemory 512mb
      --maxmemory-policy allkeys-lru
      --save 60 1000
    volumes:
      - redis_data:/data
    networks:
      - social-app-network
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 10s
      timeout: 5s
      retries: 5
    deploy:
      resources:
        limits:
          cpus: '1'
          memory: 1G
        reservations:
          cpus: '0.25'
          memory: 256M

  # ==================== 对象存储 ====================
  minio:
    image: minio/minio:latest
    container_name: social-app-minio
    restart: unless-stopped
    ports:
      - "9000:9000"
      - "9001:9001"
    environment:
      MINIO_ROOT_USER: ${MINIO_ACCESS_KEY:-minioadmin}
      MINIO_ROOT_PASSWORD: ${MINIO_SECRET_KEY:-minioadmin}
    command: server /data --console-address ":9001"
    volumes:
      - minio_data:/data
    networks:
      - social-app-network
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:9000/minio/health/live"]
      interval: 30s
      timeout: 20s
      retries: 3
    deploy:
      resources:
        limits:
          cpus: '1'
          memory: 1G
        reservations:
          cpus: '0.25'
          memory: 256M

  # ==================== 反向代理 ====================
  nginx:
    image: nginx:alpine
    container_name: social-app-nginx
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx/nginx.conf:/etc/nginx/nginx.conf:ro
      - ./nginx/conf.d:/etc/nginx/conf.d:ro
      - ./nginx/ssl:/etc/nginx/ssl:ro
      - ./logs/nginx:/var/log/nginx
    depends_on:
      - server
    networks:
      - social-app-network
    healthcheck:
      test: ["CMD", "nginx", "-t"]
      interval: 30s
      timeout: 10s
      retries: 3

networks:
  social-app-network:
    driver: bridge
    ipam:
      config:
        - subnet: 172.28.0.0/16

volumes:
  postgres_data:
    driver: local
  redis_data:
    driver: local
  minio_data:
    driver: local
```

### 5.3 Nginx 配置

**nginx/nginx.conf:**

```nginx
user nginx;
worker_processes auto;
error_log /var/log/nginx/error.log warn;
pid /var/run/nginx.pid;

events {
    worker_connections 10240;
    use epoll;
    multi_accept on;
}

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    log_format main '$remote_addr - $remote_user [$time_local] "$request" '
                    '$status $body_bytes_sent "$http_referer" '
                    '"$http_user_agent" "$http_x_forwarded_for" '
                    'rt=$request_time uct="$upstream_connect_time" '
                    'uht="$upstream_header_time" urt="$upstream_response_time"';

    access_log /var/log/nginx/access.log main;

    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;

    # Gzip 压缩
    gzip on;
    gzip_vary on;
    gzip_proxied any;
    gzip_comp_level 6;
    gzip_types text/plain text/css text/xml application/json application/javascript 
               application/xml application/xml+rss text/javascript application/x-javascript;

    # 安全头
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;

    # 限流
    limit_req_zone $binary_remote_addr zone=api:10m rate=10r/s;
    limit_conn_zone $binary_remote_addr zone=conn:10m;

    # 上传大小限制
    client_max_body_size 10M;

    include /etc/nginx/conf.d/*.conf;
}
```

**nginx/conf.d/default.conf:**

```nginx
# 上游服务器
upstream backend {
    least_conn;
    server server:8080 max_fails=3 fail_timeout=30s;
    keepalive 32;
}

# HTTP 重定向到 HTTPS
server {
    listen 80;
    server_name yourdomain.com www.yourdomain.com;
    
    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }
    
    location / {
        return 301 https://$server_name$request_uri;
    }
}

# HTTPS 主配置
server {
    listen 443 ssl http2;
    server_name yourdomain.com www.yourdomain.com;

    # SSL 证书
    ssl_certificate /etc/nginx/ssl/cert.pem;
    ssl_certificate_key /etc/nginx/ssl/key.pem;

    # SSL 配置
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers off;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 1d;
    ssl_session_tickets off;

    # HSTS
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;

    # 日志
    access_log /var/log/nginx/access.log main;
    error_log /var/log/nginx/error.log warn;

    # API 接口
    location /api/ {
        limit_req zone=api burst=20 nodelay;
        limit_conn conn 10;

        proxy_pass http://backend;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header Connection "";

        proxy_connect_timeout 30s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;

        proxy_buffering on;
        proxy_buffer_size 4k;
        proxy_buffers 8 32k;
    }

    # WebSocket 连接
    location /ws {
        proxy_pass http://backend;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        proxy_connect_timeout 60s;
        proxy_send_timeout 3600s;
        proxy_read_timeout 3600s;
    }

    # 健康检查
    location /health {
        proxy_pass http://backend;
        access_log off;
    }

    # Swagger 文档
    location /swagger/ {
        proxy_pass http://backend;
        proxy_set_header Host $host;
    }

    # 静态文件
    location / {
        root /usr/share/nginx/html;
        try_files $uri $uri/ /index.html;
        
        # 缓存
        location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$ {
            expires 1y;
            add_header Cache-Control "public, immutable";
        }
    }
}
```

### 5.4 服务端 Dockerfile

**server/Dockerfile:**

```dockerfile
# 构建阶段
FROM golang:1.21-alpine AS builder

# 安装依赖
RUN apk add --no-cache git gcc musl-dev

WORKDIR /app

# 复制依赖文件
COPY go.mod go.sum ./
RUN go mod download

# 复制源代码
COPY . .

# 构建
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -ldflags="-w -s" -o server ./cmd/server

# 运行阶段
FROM alpine:latest

# 安装必要工具
RUN apk --no-cache add ca-certificates tzdata wget

# 创建非 root 用户
RUN addgroup -g 1000 appgroup && \
    adduser -u 1000 -G appgroup -D appuser

WORKDIR /app

# 复制二进制文件
COPY --from=builder /app/server .

# 创建日志目录
RUN mkdir -p /var/log/social-app && \
    chown -R appuser:appgroup /app /var/log/social-app

# 切换用户
USER appuser

# 暴露端口
EXPOSE 8080

# 健康检查
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD wget -q --spider http://localhost:8080/health || exit 1

# 启动服务
ENTRYPOINT ["./server"]
```

---

## 6. 服务管理

### 6.1 常用命令

```bash
# 启动服务
docker-compose up -d

# 停止服务
docker-compose down

# 重启服务
docker-compose restart

# 查看状态
docker-compose ps

# 查看日志
docker-compose logs -f [service_name]

# 进入容器
docker-compose exec server sh
docker-compose exec postgres bash

# 重新构建
docker-compose build --no-cache server
docker-compose up -d server
```

### 6.2 服务脚本

**scripts/deploy.sh:**

```bash
#!/bin/bash
set -e

PROJECT_DIR="/opt/social-app"
BACKUP_DIR="/opt/backups"
DATE=$(date +%Y%m%d_%H%M%S)

echo "========================================="
echo "  社交应用部署脚本"
echo "  时间: $(date)"
echo "========================================="

cd $PROJECT_DIR

# 拉取最新代码
echo "[1/6] 拉取最新代码..."
git pull origin main

# 备份数据库
echo "[2/6] 备份数据库..."
mkdir -p $BACKUP_DIR
docker-compose exec -T postgres pg_dump -U postgres social_app > $BACKUP_DIR/db_$DATE.sql

# 构建镜像
echo "[3/6] 构建镜像..."
docker-compose build --no-cache server

# 停止旧服务
echo "[4/6] 停止旧服务..."
docker-compose stop server

# 启动新服务
echo "[5/6] 启动新服务..."
docker-compose up -d server

# 等待启动
echo "[6/6] 等待服务启动..."
sleep 10

# 健康检查
if curl -sf http://localhost:8080/health > /dev/null; then
    echo "✅ 部署成功！"
    echo "健康检查: http://localhost:8080/health"
else
    echo "❌ 部署失败，正在回滚..."
    docker-compose logs --tail 100 server
    exit 1
fi

# 清理旧备份（保留最近7天）
find $BACKUP_DIR -name "db_*.sql" -mtime +7 -delete

echo "========================================="
echo "  部署完成！"
echo "========================================="
```

---

## 7. 数据备份

### 7.1 自动备份脚本

**scripts/backup.sh:**

```bash
#!/bin/bash
set -e

BACKUP_DIR="/opt/backups"
DATE=$(date +%Y%m%d_%H%M%S)
RETENTION_DAYS=30

mkdir -p $BACKUP_DIR

echo "开始备份..."

# 备份 PostgreSQL
echo "备份 PostgreSQL..."
docker-compose exec -T postgres pg_dump -U postgres social_app | gzip > $BACKUP_DIR/postgres_$DATE.sql.gz

# 备份 Redis
echo "备份 Redis..."
docker-compose exec -T redis redis-cli BGSAVE
sleep 5
docker cp social-app-redis:/data/dump.rdb $BACKUP_DIR/redis_$DATE.rdb

# 备份 MinIO
echo "备份 MinIO..."
docker-compose exec -T minio mc mirror local/social-app $BACKUP_DIR/minio_$DATE/

# 清理旧备份
echo "清理旧备份..."
find $BACKUP_DIR -name "*.gz" -mtime +$RETENTION_DAYS -delete
find $BACKUP_DIR -name "*.rdb" -mtime +$RETENTION_DAYS -delete
find $BACKUP_DIR -type d -name "minio_*" -mtime +$RETENTION_DAYS -exec rm -rf {} +

echo "备份完成！"
ls -lh $BACKUP_DIR
```

### 7.2 恢复脚本

**scripts/restore.sh:**

```bash
#!/bin/bash
set -e

BACKUP_FILE=$1

if [ -z "$BACKUP_FILE" ]; then
    echo "用法: ./restore.sh <backup_file.sql.gz>"
    exit 1
fi

echo "警告: 此操作将覆盖当前数据库！"
read -p "确认继续? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    echo "已取消"
    exit 0
fi

echo "恢复数据库..."
zcat $BACKUP_FILE | docker-compose exec -T postgres psql -U postgres social_app

echo "恢复完成！"
```

### 7.3 定时备份 (Crontab)

```bash
# 编辑 crontab
crontab -e

# 添加定时任务（每天凌晨2点备份）
0 2 * * * /opt/social-app/scripts/backup.sh >> /var/log/social-app/backup.log 2>&1
```

---

## 8. 监控告警

### 8.1 Prometheus 配置

**monitoring/prometheus.yml:**

```yaml
global:
  scrape_interval: 15s
  evaluation_interval: 15s

alerting:
  alertmanagers:
    - static_configs:
        - targets:
          - alertmanager:9093

rule_files:
  - /etc/prometheus/rules.yml

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'social-app'
    static_configs:
      - targets: ['server:8080']
    metrics_path: '/metrics'

  - job_name: 'postgres'
    static_configs:
      - targets: ['postgres-exporter:9187']

  - job_name: 'redis'
    static_configs:
      - targets: ['redis-exporter:9121']

  - job_name: 'nginx'
    static_configs:
      - targets: ['nginx-exporter:9113']
```

### 8.2 告警规则

**monitoring/rules.yml:**

```yaml
groups:
  - name: social-app-alerts
    rules:
      - alert: ServiceDown
        expr: up == 0
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "服务宕机"
          description: "服务 {{ $labels.job }} 已宕机超过1分钟"

      - alert: HighCPUUsage
        expr: 100 - (avg by(instance) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > 80
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "CPU 使用率过高"
          description: "CPU 使用率 {{ $value }}%"

      - alert: HighMemoryUsage
        expr: (1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100 > 85
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "内存使用率过高"
          description: "内存使用率 {{ $value }}%"

      - alert: DiskSpaceLow
        expr: (1 - (node_filesystem_avail_bytes{fstype!="tmpfs"} / node_filesystem_size_bytes{fstype!="tmpfs"})) * 100 > 85
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "磁盘空间不足"
          description: "磁盘使用率 {{ $value }}%"

      - alert: DatabaseConnectionsHigh
        expr: pg_stat_activity_count > 80
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "数据库连接数过高"
          description: "当前连接数: {{ $value }}"
```

### 8.3 健康检查脚本

**scripts/health-check.sh:**

```bash
#!/bin/bash

SERVICES=(
    "server:http://localhost:8080/health"
    "postgres:localhost:5432"
    "redis:localhost:6379"
    "minio:http://localhost:9000/minio/health/live"
)

ALERT_WEBHOOK="https://your-webhook-url"

for service in "${SERVICES[@]}"; do
    name="${service%%:*}"
    endpoint="${service#*:}"
    
    case $name in
        postgres)
            if docker-compose exec -T postgres pg_isready -q; then
                echo "✅ $name: 正常"
            else
                echo "❌ $name: 异常"
                curl -s -X POST $ALERT_WEBHOOK -d "{\"text\":\"$name 服务异常\"}"
            fi
            ;;
        redis)
            if docker-compose exec -T redis redis-cli ping | grep -q PONG; then
                echo "✅ $name: 正常"
            else
                echo "❌ $name: 异常"
                curl -s -X POST $ALERT_WEBHOOK -d "{\"text\":\"$name 服务异常\"}"
            fi
            ;;
        *)
            if curl -sf "$endpoint" > /dev/null; then
                echo "✅ $name: 正常"
            else
                echo "❌ $name: 异常"
                curl -s -X POST $ALERT_WEBHOOK -d "{\"text\":\"$name 服务异常\"}"
            fi
            ;;
    esac
done
```

---

## 9. 故障排查

### 9.1 常见问题

#### 问题 1: 服务无法启动

```bash
# 检查日志
docker-compose logs server

# 检查端口占用
netstat -tlnp | grep 8080

# 检查容器状态
docker-compose ps

# 检查资源使用
docker stats
```

#### 问题 2: 数据库连接失败

```bash
# 检查数据库状态
docker-compose exec postgres pg_isready

# 检查连接数
docker-compose exec postgres psql -U postgres -c "SELECT count(*) FROM pg_stat_activity;"

# 检查数据库日志
docker-compose logs postgres --tail 100
```

#### 问题 3: WebSocket 连接断开

```bash
# 检查 Nginx 配置
docker-compose exec nginx nginx -t

# 检查超时配置
grep -r "timeout" nginx/conf.d/

# 检查网络
docker network inspect social-app-network
```

### 9.2 日志分析

```bash
# 查看错误日志
docker-compose logs server | grep -i error

# 查看慢请求
docker-compose logs nginx | grep "request_time" | awk -F'"' '{print $6}' | sort -n | tail -20

# 数据库慢查询
docker-compose exec postgres psql -U postgres -c "SELECT * FROM pg_stat_statements ORDER BY total_exec_time DESC LIMIT 10;"
```

---

## 10. 安全加固

### 10.1 网络安全

```bash
# 配置防火墙
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow 22/tcp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw enable

# 限制数据库访问
sudo ufw deny 5432
sudo ufw deny 6379
sudo ufw deny 9000
```

### 10.2 SSL 配置

```bash
# 使用 Let's Encrypt
sudo apt install certbot

# 获取证书
sudo certbot certonly --standalone -d yourdomain.com -d www.yourdomain.com

# 自动续期
sudo crontab -e
0 0 1 * * certbot renew --quiet && docker-compose restart nginx
```

### 10.3 安全配置

```bash
# .env 安全配置
JWT_SECRET=$(openssl rand -base64 32)
DB_PASSWORD=$(openssl rand -base64 16)
MINIO_SECRET_KEY=$(openssl rand -base64 24)

# 更新 .env
sed -i "s/JWT_SECRET=.*/JWT_SECRET=$JWT_SECRET/" .env
sed -i "s/DB_PASSWORD=.*/DB_PASSWORD=$DB_PASSWORD/" .env
sed -i "s/MINIO_SECRET_KEY=.*/MINIO_SECRET_KEY=$MINIO_SECRET_KEY/" .env
```

---

## 11. 性能优化

### 11.1 数据库优化

```sql
-- 创建索引
CREATE INDEX idx_messages_conversation_created ON messages(conversation_id, created_at DESC);
CREATE INDEX idx_conversation_members_user ON conversation_members(user_id);
CREATE INDEX idx_messages_sender ON messages(sender_id);

-- 定期清理
VACUUM ANALYZE;

-- 连接池配置 (postgresql.conf)
max_connections = 200
shared_buffers = 256MB
effective_cache_size = 768MB
maintenance_work_mem = 64MB
checkpoint_completion_target = 0.9
wal_buffers = 16MB
default_statistics_target = 100
random_page_cost = 1.1
effective_io_concurrency = 200
work_mem = 2621kB
min_wal_size = 1GB
max_wal_size = 4GB
```

### 11.2 Redis 优化

```
# redis.conf
maxmemory 1gb
maxmemory-policy allkeys-lru
save 900 1
save 300 10
save 60 10000
```

### 11.3 Nginx 优化

```nginx
# nginx.conf
worker_processes auto;
worker_rlimit_nofile 65535;

events {
    worker_connections 10240;
    use epoll;
    multi_accept on;
}

http {
    keepalive_timeout 65;
    keepalive_requests 1000;
    
    open_file_cache max=10000 inactive=30s;
    open_file_cache_valid 60s;
    open_file_cache_min_uses 2;
    open_file_cache_errors on;
}
```

---

## 12. 升级指南

### 12.1 版本升级

```bash
# 1. 备份数据
/opt/social-app/scripts/backup.sh

# 2. 拉取新版本
git fetch --tags
git checkout v1.1.0  # 替换为目标版本

# 3. 检查配置变更
git diff v1.0.0 v1.1.0 -- .env.example docker-compose.yml

# 4. 更新配置
vim .env

# 5. 执行数据库迁移
docker-compose run --rm server migrate

# 6. 重新部署
docker-compose up -d --build

# 7. 验证
curl http://localhost:8080/health
```

### 12.2 回滚

```bash
# 回滚到上一版本
git checkout v1.0.0
docker-compose up -d --build

# 恢复数据库
/opt/social-app/scripts/restore.sh /opt/backups/db_20260318.sql.gz
```

---

## 附录

### A. 端口列表

| 端口 | 服务 | 协议 | 说明 |
|------|------|------|------|
| 80 | Nginx | HTTP | Web 服务 |
| 443 | Nginx | HTTPS | Web 服务 (SSL) |
| 8080 | Server | HTTP | API 服务 |
| 5432 | PostgreSQL | TCP | 数据库 |
| 6379 | Redis | TCP | 缓存 |
| 9000 | MinIO | HTTP | 对象存储 API |
| 9001 | MinIO | HTTP | MinIO Console |

### B. 环境变量完整列表

参见 [5.1 环境变量](#51-环境变量-env)

### C. API 文档

访问: https://yourdomain.com/swagger/index.html

### D. 技术支持

- 文档: https://docs.yourdomain.com
- Issues: https://github.com/your-org/social-app/issues
- Email: support@yourdomain.com