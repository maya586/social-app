@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

echo ========================================
echo    Social App Deploy Script (Windows)
echo ========================================
echo.

REM Check Docker
docker --version >nul 2>&1
if errorlevel 1 (
    echo ERROR: Docker not installed, please install Docker Desktop first
    pause
    exit /b 1
)

docker-compose --version >nul 2>&1
if errorlevel 1 (
    echo ERROR: Docker Compose not installed
    pause
    exit /b 1
)

echo Docker version:
docker --version
echo Docker Compose version:
docker-compose --version
echo.

REM Change to deploy directory
cd /d "%~dp0"

REM Check Docker daemon.json for mirror (China users)
echo Checking Docker mirror configuration...
echo.
echo IMPORTANT: If you are in China, please configure Docker mirror:
echo.
echo 1. Open Docker Desktop
echo 2. Go to Settings -^> Docker Engine
echo 3. Add the following to the JSON:
echo.
echo   "registry-mirrors": [
echo     "https://docker.1ms.run",
echo     "https://docker.xuanyuan.me"
echo   ]
echo.
echo 4. Click "Apply and Restart"
echo.
pause

REM Check .env file
if not exist .env (
    echo Creating .env from template...
    copy .env.example .env >nul
    echo Please edit .env file to configure your settings
    pause
)

REM Create directories
echo Creating directories...
if not exist ssl mkdir ssl
if not exist data\postgres mkdir data\postgres
if not exist data\redis mkdir data\redis
if not exist data\minio mkdir data\minio
if not exist logs mkdir logs

REM Pull images
echo Pulling base images...
docker-compose pull
if errorlevel 1 (
    echo.
    echo WARNING: Failed to pull images. This may be due to network issues.
    echo Please configure Docker mirror and try again.
    echo.
    pause
)

REM Build application image
echo Building application image...
docker-compose build
if errorlevel 1 (
    echo.
    echo ERROR: Build failed. Please check network connection and Docker mirror.
    pause
    exit /b 1
)

REM Stop old containers
echo Stopping old containers...
docker-compose down

REM Start services
echo Starting services...
docker-compose up -d

REM Wait for services
echo Waiting for services to start...
timeout /t 15 /nobreak >nul

REM Check status
echo Checking service status...
docker-compose ps

REM Health check
echo Running health check...
set MAX_RETRIES=30
set RETRY_COUNT=0

:health_check
curl -sf http://localhost:8080/health >nul 2>&1
if errorlevel 1 (
    set /a RETRY_COUNT+=1
    if !RETRY_COUNT! geq %MAX_RETRIES% (
        echo Health check failed, checking logs...
        docker-compose logs --tail=50 server
        pause
        exit /b 1
    )
    echo Waiting for services... ^(!RETRY_COUNT!/%MAX_RETRIES%^)
    timeout /t 2 /nobreak >nul
    goto health_check
)

echo Health check passed!
echo.
echo ========================================
echo           Deploy Complete!
echo ========================================
echo.
echo Access URLs:
echo   API:      http://localhost:8080/api/v1
echo   Swagger:  http://localhost:8080/swagger/index.html
echo   WebSocket: ws://localhost:8080/ws
echo.
echo MinIO Console: http://localhost:9001
echo.
echo Useful commands:
echo   View logs:  docker-compose logs -f server
echo   Restart:    docker-compose restart
echo   Stop:       docker-compose down
echo   Status:     docker-compose ps
echo.
pause