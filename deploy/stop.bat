@echo off
cd /d "%~dp0"

echo 停止所有服务...
docker-compose down

echo 清理旧镜像...
docker-compose down --rmi local

echo 完成
docker-compose ps
pause