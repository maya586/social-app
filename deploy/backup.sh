#!/bin/bash

# 备份脚本
# 使用方法: ./backup.sh [backup_name]

BACKUP_DIR="./backups"
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_NAME="${1:-backup_$DATE}"

cd "$(dirname "$0")"

echo "开始备份: $BACKUP_NAME"

# 创建备份目录
mkdir -p "$BACKUP_DIR/$BACKUP_NAME"

# 备份 PostgreSQL
echo "备份 PostgreSQL..."
docker-compose exec -T postgres pg_dump -U postgres social_app > "$BACKUP_DIR/$BACKUP_NAME/database.sql"

# 备份 Redis
echo "备份 Redis..."
docker-compose exec -T redis redis-cli BGSAVE
sleep 2
docker cp social-app-redis:/data/dump.rdb "$BACKUP_DIR/$BACKUP_NAME/redis.rdb"

# 备份 MinIO
echo "备份 MinIO 配置..."
# MinIO 数据较大，建议使用 mc mirror 命令单独备份

# 压缩备份
echo "压缩备份文件..."
cd "$BACKUP_DIR"
tar -czf "$BACKUP_NAME.tar.gz" "$BACKUP_NAME"
rm -rf "$BACKUP_NAME"

echo "备份完成: $BACKUP_DIR/$BACKUP_NAME.tar.gz"

# 清理 7 天前的备份
find "$BACKUP_DIR" -name "*.tar.gz" -mtime +7 -delete
echo "已清理 7 天前的旧备份"