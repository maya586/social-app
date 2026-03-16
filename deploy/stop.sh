#!/bin/bash

cd "$(dirname "$0")"

echo "停止所有服务..."
docker-compose down

echo "清理旧镜像..."
docker-compose down --rmi local

echo "清理数据卷 (危险操作，已跳过)"
# docker-compose down -v

echo "完成"
docker-compose ps