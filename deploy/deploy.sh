#!/bin/bash

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}    Social App 一键部署脚本           ${NC}"
echo -e "${GREEN}========================================${NC}"

# 检查 Docker 是否安装
if ! command -v docker &> /dev/null; then
    echo -e "${RED}错误: Docker 未安装，请先安装 Docker${NC}"
    exit 1
fi

if ! command -v docker-compose &> /dev/null; then
    echo -e "${RED}错误: Docker Compose 未安装，请先安装 Docker Compose${NC}"
    exit 1
fi

echo -e "${YELLOW}Docker 版本:${NC}"
docker --version
echo -e "${YELLOW}Docker Compose 版本:${NC}"
docker-compose --version

# 切换到部署目录
cd "$(dirname "$0")"

# 检查 .env 文件
if [ ! -f .env ]; then
    echo -e "${YELLOW}未找到 .env 文件，正在从模板创建...${NC}"
    cp .env.example .env
    echo -e "${YELLOW}请编辑 .env 文件配置您的环境变量${NC}"
    echo -e "${YELLOW}特别注意以下配置:${NC}"
    echo "  - DB_PASSWORD: 数据库密码"
    echo "  - JWT_SECRET: JWT 密钥 (至少32位)"
    echo "  - MINIO_SECRET_KEY: MinIO 密钥"
    echo ""
    read -p "按回车继续..."
fi

# 创建必要的目录
echo -e "${YELLOW}创建必要的目录...${NC}"
mkdir -p ssl
mkdir -p data/postgres
mkdir -p data/redis
mkdir -p data/minio
mkdir -p logs

# 生成自签名 SSL 证书（如果不存在）
if [ ! -f ssl/cert.pem ] || [ ! -f ssl/key.pem ]; then
    echo -e "${YELLOW}生成自签名 SSL 证书...${NC}"
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout ssl/key.pem \
        -out ssl/cert.pem \
        -subj "/C=CN/ST=Beijing/L=Beijing/O=SocialApp/OU=IT/CN=localhost" \
        2>/dev/null
    echo -e "${GREEN}SSL 证书已生成${NC}"
fi

# 拉取最新镜像
echo -e "${YELLOW}拉取基础镜像...${NC}"
docker-compose pull

# 构建应用镜像
echo -e "${YELLOW}构建应用镜像...${NC}"
docker-compose build --no-cache

# 停止旧容器
echo -e "${YELLOW}停止旧容器...${NC}"
docker-compose down

# 启动服务
echo -e "${YELLOW}启动服务...${NC}"
docker-compose up -d

# 等待服务启动
echo -e "${YELLOW}等待服务启动...${NC}"
sleep 10

# 检查服务状态
echo -e "${YELLOW}检查服务状态...${NC}"
docker-compose ps

# 健康检查
echo -e "${YELLOW}执行健康检查...${NC}"
MAX_RETRIES=30
RETRY_COUNT=0

while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    if curl -sf http://localhost:8080/health > /dev/null 2>&1; then
        echo -e "${GREEN}服务健康检查通过!${NC}"
        break
    fi
    RETRY_COUNT=$((RETRY_COUNT + 1))
    echo -e "${YELLOW}等待服务就绪... ($RETRY_COUNT/$MAX_RETRIES)${NC}"
    sleep 2
done

if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
    echo -e "${RED}服务健康检查失败，请检查日志${NC}"
    docker-compose logs --tail=50 server
    exit 1
fi

# 显示访问信息
echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}           部署完成!                  ${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${YELLOW}访问地址:${NC}"
echo "  API:      http://localhost:8080/api/v1"
echo "  Swagger:  http://localhost:8080/swagger/index.html"
echo "  WebSocket: ws://localhost:8080/ws"
echo ""
echo -e "${YELLOW}管理界面:${NC}"
echo "  MinIO:    http://localhost:9001 (minioadmin / your_minio_secret_key)"
echo ""
echo -e "${YELLOW}常用命令:${NC}"
echo "  查看日志:     docker-compose logs -f server"
echo "  重启服务:     docker-compose restart"
echo "  停止服务:     docker-compose down"
echo "  查看状态:     docker-compose ps"
echo ""