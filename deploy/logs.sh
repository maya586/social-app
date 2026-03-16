#!/bin/bash

# 日志管理脚本

LOG_DIR="./logs"
MAX_LOG_SIZE="100M"
MAX_LOG_FILES=10

cd "$(dirname "$0")"

echo "日志管理..."

# 创建日志目录
mkdir -p "$LOG_DIR"

# 显示当前日志大小
echo "=== 日志文件大小 ==="
du -sh "$LOG_DIR"/* 2>/dev/null || echo "暂无日志文件"

# 显示最近的日志
echo ""
echo "=== 服务器最近日志 (最后 50 行) ==="
if [ -f "$LOG_DIR/server/app.log" ]; then
    tail -n 50 "$LOG_DIR/server/app.log"
else
    docker-compose logs --tail=50 server
fi

# 显示容器日志统计
echo ""
echo "=== 容器日志统计 ==="
docker-compose logs --tail=0 2>/dev/null