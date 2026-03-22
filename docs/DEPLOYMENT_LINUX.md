# Linux 服务端 Docker 部署指南

## 一、环境要求

- Linux 服务器（Ubuntu 20.04+ / CentOS 7+ / Debian 10+）
- 至少 2GB 内存
- 开放端口：8080（API）、9001（MinIO 控制台，可选）

## 二、安装 Docker

```bash
# 安装 Docker
curl -fsSL https://get.docker.com | sh

# 启动 Docker
systemctl start docker
systemctl enable docker

# 验证安装
docker --version
```

## 三、部署步骤

### 1. 克隆代码

```bash
git clone https://github.com/maya586/social-app.git
cd social-app
```

### 2. 一键部署

```bash
chmod +x deploy.sh
./deploy.sh
```

### 3. 手动部署（如果脚本失败）

```bash
# 构建并启动所有服务
docker compose up -d --build

# 查看服务状态
docker compose ps

# 查看日志
docker compose logs -f server
```

## 四、验证部署

```bash
# 测试 API 健康检查
curl http://localhost:8080/health

# 预期返回: {"status":"ok"}

# 测试用户注册
curl -X POST http://localhost:8080/api/v1/auth/register \
  -H "Content-Type: application/json" \
  -d '{"phone":"13800138000","password":"123456","nickname":"test"}'
```

## 五、服务管理

```bash
# 查看服务状态
docker compose ps

# 查看日志
docker compose logs -f server

# 重启服务
docker compose restart server

# 停止所有服务
docker compose down

# 停止并删除数据
docker compose down -v
```

## 六、配置说明

### 环境变量（在 docker-compose.yml 中配置）

| 变量 | 默认值 | 说明 |
|------|--------|------|
| SERVER_PORT | 8080 | API 服务端口 |
| DB_HOST | postgres | 数据库主机（Docker 网络内使用服务名） |
| DB_PORT | 5432 | 数据库端口 |
| DB_USER | postgres | 数据库用户名 |
| DB_PASSWORD | postgres | 数据库密码 |
| DB_NAME | social_app | 数据库名称 |
| REDIS_ADDR | redis:6379 | Redis 地址 |
| JWT_SECRET | your_jwt_secret... | JWT 密钥（请修改） |
| MINIO_ENDPOINT | minio:9000 | MinIO 地址 |
| MINIO_ACCESS_KEY | minioadmin | MinIO 用户名 |
| MINIO_SECRET_KEY | minioadmin | MinIO 密码 |

### 修改 JWT 密钥（生产环境必须修改）

编辑 `docker-compose.yml`，修改 `JWT_SECRET` 的值：

```yaml
- JWT_SECRET=your_secure_random_string_at_least_32_characters
```

## 七、防火墙配置

```bash
# Ubuntu/Debian
sudo ufw allow 8080/tcp
sudo ufw allow 9001/tcp  # MinIO 控制台（可选）

# CentOS/RHEL
sudo firewall-cmd --permanent --add-port=8080/tcp
sudo firewall-cmd --permanent --add-port=9001/tcp
sudo firewall-cmd --reload
```

## 八、数据备份

```bash
# 备份 PostgreSQL
docker exec social-postgres pg_dump -U postgres social_app > backup_$(date +%Y%m%d).sql

# 恢复 PostgreSQL
cat backup_20260320.sql | docker exec -i social-postgres psql -U postgres social_app
```

## 九、常见问题

### 1. 数据库连接失败

确保使用 Docker 网络服务名：
- `DB_HOST=postgres`（不是 localhost）
- `REDIS_ADDR=redis:6379`
- `MINIO_ENDPOINT=minio:9000`

### 2. 端口被占用

```bash
# 查看端口占用
netstat -tlnp | grep 8080

# 修改端口（编辑 docker-compose.yml）
ports:
  - "8081:8080"  # 改为其他端口
```

### 3. 查看详细日志

```bash
# 服务端日志
docker compose logs -f server

# 数据库日志
docker compose logs -f postgres

# 所有服务日志
docker compose logs -f
```

## 十、更新部署

```bash
# 拉取最新代码
git pull

# 重新构建并部署
docker compose up -d --build
```

## 十一、客户端配置

修改客户端 `api_config.dart`，设置服务器地址：

```dart
class ApiConfig {
  static const String baseUrl = 'http://YOUR_SERVER_IP:8080/api/v1';
  static const String wsUrl = 'ws://YOUR_SERVER_IP:8080/ws';
}
```

## 十二、生产环境建议

1. **使用 HTTPS**：配置 Nginx 反向代理和 SSL 证书
2. **修改默认密码**：修改数据库、Redis、MinIO 的默认密码
3. **修改 JWT 密钥**：使用强随机字符串
4. **定期备份**：设置自动备份任务
5. **监控日志**：配置日志收集和告警