# Social App 部署指南

## 目录结构

```
deploy/
├── .env.example          # 环境变量模板
├── docker-compose.yml    # Docker Compose 配置
├── docker-compose.prod.yml # 生产环境配置
├── nginx.conf            # Nginx 配置
├── deploy.sh             # Linux 一键部署脚本
├── deploy.bat            # Windows 一键部署脚本
├── stop.sh               # Linux 停止脚本
├── stop.bat              # Windows 停止脚本
├── backup.sh             # 备份脚本
├── logs.sh               # 日志管理脚本
├── init-db/              # 数据库初始化脚本
│   └── 01-init.sql
├── ssl/                  # SSL 证书目录
└── backups/              # 备份文件目录
```

---

## 快速开始

### 前置要求

- Docker 20.10+
- Docker Compose 2.0+
- 至少 4GB 可用内存
- 至少 10GB 可用磁盘空间

### 一键部署

**Linux/macOS:**
```bash
cd deploy
chmod +x deploy.sh
./deploy.sh
```

**Windows:**
```cmd
cd deploy
deploy.bat
```

---

## 详细配置

### 1. 环境变量配置

复制环境变量模板并修改:
```bash
cp .env.example .env
```

**必须修改的配置:**

| 变量 | 说明 | 示例 |
|------|------|------|
| `DB_PASSWORD` | 数据库密码 | `your_secure_password` |
| `JWT_SECRET` | JWT 密钥 (≥32位) | `your_jwt_secret_key_at_least_32_characters` |
| `MINIO_SECRET_KEY` | MinIO 密钥 | `your_minio_secret_key` |

### 2. SSL 证书配置

**开发环境 (自签名证书):**
```bash
# 自动生成 (部署脚本会自动执行)
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout ssl/key.pem -out ssl/cert.pem \
  -subj "/C=CN/ST=Beijing/L=Beijing/O=SocialApp/CN=your-domain.com"
```

**生产环境 (Let's Encrypt):**
```bash
# 安装 certbot
sudo apt install certbot

# 获取证书
sudo certbot certonly --standalone -d your-domain.com

# 复制证书
sudo cp /etc/letsencrypt/live/your-domain.com/fullchain.pem ssl/cert.pem
sudo cp /etc/letsencrypt/live/your-domain.com/privkey.pem ssl/key.pem
```

### 3. Firebase 推送配置 (可选)

将 Firebase 凭证文件放置在:
```
deploy/firebase-credentials.json
```

---

## 服务架构

```
                    ┌─────────────┐
                    │   Nginx     │ :80, :443
                    │ (反向代理)   │
                    └──────┬──────┘
                           │
                    ┌──────▼──────┐
                    │   Server    │ :8080
                    │  (Go API)   │
                    └──────┬──────┘
                           │
         ┌─────────────────┼─────────────────┐
         │                 │                 │
    ┌────▼────┐      ┌─────▼─────┐     ┌─────▼─────┐
    │PostgreSQL│      │   Redis   │     │   MinIO   │
    │   :5432  │      │   :6379   │     │ :9000,9001│
    └──────────┘      └───────────┘     └───────────┘
```

---

## 常用命令

### 服务管理

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
docker-compose logs -f server
docker-compose logs -f nginx
```

### 数据库管理

```bash
# 连接数据库
docker-compose exec postgres psql -U postgres -d social_app

# 备份数据库
docker-compose exec postgres pg_dump -U postgres social_app > backup.sql

# 恢复数据库
cat backup.sql | docker-compose exec -T postgres psql -U postgres social_app
```

### Redis 管理

```bash
# 连接 Redis
docker-compose exec redis redis-cli

# 查看所有键
docker-compose exec redis redis-cli KEYS '*'

# 清空缓存
docker-compose exec redis redis-cli FLUSHALL
```

### MinIO 管理

```bash
# 创建存储桶
docker-compose exec minio mc alias set local http://localhost:9000 minioadmin minioadmin
docker-compose exec minio mc mb local/social-app
```

---

## 生产环境部署

### 1. 使用生产配置

```bash
docker-compose -f docker-compose.yml -f docker-compose.prod.yml up -d
```

### 2. 资源限制

生产配置已设置以下资源限制:

| 服务 | CPU 限制 | 内存限制 |
|------|----------|----------|
| Nginx | 0.5 核 | 256MB |
| Server | 2 核 | 1GB |
| PostgreSQL | 2 核 | 2GB |
| Redis | 1 核 | 512MB |
| MinIO | 1 核 | 1GB |

### 3. 日志轮转

生产配置已启用日志轮转:
- 单文件最大: 50MB
- 保留文件数: 5 个

### 4. 健康检查

所有服务都配置了健康检查:
- 检查间隔: 10 秒
- 超时时间: 5 秒
- 重试次数: 5 次

---

## 监控与告警

### 健康检查端点

| 端点 | 说明 |
|------|------|
| `/health` | 服务健康状态 |
| `/swagger/index.html` | API 文档 |

### Prometheus 指标 (可选)

在 `docker-compose.yml` 中添加 Prometheus:

```yaml
  prometheus:
    image: prom/prometheus
    ports:
      - "9090:9090"
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml
```

---

## 备份与恢复

### 自动备份

设置 cron 任务:
```bash
# 每天凌晨 2 点备份
0 2 * * * /path/to/deploy/backup.sh daily_backup
```

### 手动备份

```bash
./backup.sh manual_backup_$(date +%Y%m%d)
```

### 恢复数据

```bash
# 解压备份
tar -xzf backups/backup_name.tar.gz

# 恢复数据库
cat backups/backup_name/database.sql | docker-compose exec -T postgres psql -U postgres social_app

# 恢复 Redis
docker cp backups/backup_name/redis.rdb social-app-redis:/data/dump.rdb
docker-compose restart redis
```

---

## 故障排除

### 服务无法启动

1. 检查端口占用:
```bash
netstat -tlnp | grep -E '80|443|8080|5432|6379|9000'
```

2. 查看日志:
```bash
docker-compose logs server
```

### 数据库连接失败

1. 检查数据库状态:
```bash
docker-compose ps postgres
docker-compose exec postgres pg_isready
```

2. 检查连接配置:
```bash
docker-compose exec server env | grep DB
```

### 内存不足

1. 检查容器资源使用:
```bash
docker stats
```

2. 调整资源限制 (修改 docker-compose.prod.yml)

---

## 安全加固

### 1. 网络安全

- 使用防火墙限制端口访问
- 仅暴露必要端口 (80, 443)

### 2. 应用安全

- 定期更新 JWT_SECRET
- 使用强密码
- 启用 HTTPS

### 3. 数据库安全

- 限制远程访问
- 定期备份
- 使用 SSL 连接

---

## 更新与升级

### 更新应用

```bash
# 拉取最新代码
git pull

# 重新构建并部署
docker-compose build --no-cache server
docker-compose up -d server
```

### 更新基础镜像

```bash
docker-compose pull
docker-compose up -d
```

---

## API 访问

部署完成后可通过以下地址访问:

| 服务 | 地址 |
|------|------|
| API | http://localhost:8080/api/v1 |
| Swagger | http://localhost:8080/swagger/index.html |
| WebSocket | ws://localhost:8080/ws |
| MinIO Console | http://localhost:9001 |

---

## 支持

如有问题，请查看:
1. 服务日志: `docker-compose logs -f`
2. 健康检查: `curl http://localhost:8080/health`
3. GitHub Issues: [项目地址]