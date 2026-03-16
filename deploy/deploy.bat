@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

echo ========================================
echo    Social App 一键部署脚本 (Windows)
echo ========================================
echo.

REM 检查 Docker 是否安装
docker --version >nul 2>&1
if errorlevel 1 (
    echo 错误: Docker 未安装，请先安装 Docker Desktop
    pause
    exit /b 1
)

docker-compose --version >nul 2>&1
if errorlevel 1 (
    echo 错误: Docker Compose 未安装
    pause
    exit /b 1
)

echo Docker 版本:
docker --version
echo Docker Compose 版本:
docker-compose --version
echo.

REM 切换到部署目录
cd /d "%~dp0"

REM 检查 .env 文件
if not exist .env (
    echo 未找到 .env 文件，正在从模板创建...
    copy .env.example .env >nul
    echo 请编辑 .env 文件配置您的环境变量
    echo 特别注意以下配置:
    echo   - DB_PASSWORD: 数据库密码
    echo   - JWT_SECRET: JWT 密钥 ^(至少32位^)
    echo   - MINIO_SECRET_KEY: MinIO 密钥
    echo.
    pause
)

REM 创建必要的目录
echo 创建必要的目录...
if not exist ssl mkdir ssl
if not exist data\postgres mkdir data\postgres
if not exist data\redis mkdir data\redis
if not exist data\minio mkdir data\minio
if not exist logs mkdir logs

REM 生成自签名 SSL 证书
if not exist ssl\cert.pem (
    echo 生成自签名 SSL 证书...
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout ssl\key.pem -out ssl\cert.pem -subj "/C=CN/ST=Beijing/L=Beijing/O=SocialApp/OU=IT/CN=localhost" 2>nul
    if errorlevel 1 (
        echo 警告: 无法生成 SSL 证书，请确保已安装 OpenSSL
    )
)

REM 拉取镜像
echo 拉取基础镜像...
docker-compose pull

REM 构建应用镜像
echo 构建应用镜像...
docker-compose build --no-cache

REM 停止旧容器
echo 停止旧容器...
docker-compose down

REM 启动服务
echo 启动服务...
docker-compose up -d

REM 等待服务启动
echo 等待服务启动...
timeout /t 10 /nobreak >nul

REM 检查服务状态
echo 检查服务状态...
docker-compose ps

REM 健康检查
echo 执行健康检查...
set MAX_RETRIES=30
set RETRY_COUNT=0

:health_check
curl -sf http://localhost:8080/health >nul 2>&1
if errorlevel 1 (
    set /a RETRY_COUNT+=1
    if !RETRY_COUNT! geq %MAX_RETRIES% (
        echo 服务健康检查失败，请检查日志
        docker-compose logs --tail=50 server
        pause
        exit /b 1
    )
    echo 等待服务就绪... ^(!RETRY_COUNT!/%MAX_RETRIES%^)
    timeout /t 2 /nobreak >nul
    goto health_check
)

echo 服务健康检查通过!
echo.
echo ========================================
echo           部署完成!
echo ========================================
echo.
echo 访问地址:
echo   API:      http://localhost:8080/api/v1
echo   Swagger:  http://localhost:8080/swagger/index.html
echo   WebSocket: ws://localhost:8080/ws
echo.
echo 管理界面:
echo   MinIO:    http://localhost:9001
echo.
echo 常用命令:
echo   查看日志:     docker-compose logs -f server
echo   重启服务:     docker-compose restart
echo   停止服务:     docker-compose down
echo   查看状态:     docker-compose ps
echo.
pause