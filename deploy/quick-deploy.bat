@echo off
echo ========================================
echo   Quick Deploy - Using Pre-built Images
echo ========================================
echo.
echo This script uses Chinese Docker mirrors
echo.

cd /d "%~dp0"

echo Step 1/5: Creating directories...
if not exist ssl mkdir ssl
if not exist data\postgres mkdir data\postgres
if not exist data\redis mkdir data\redis
if not exist data\minio mkdir data\minio
if not exist logs mkdir logs

echo Step 2/5: Checking .env file...
if not exist .env (
    copy .env.example .env >nul
    echo Created .env file. You may edit it later.
)

echo Step 3/5: Pulling images with mirror...
echo.
echo If pull fails, please configure Docker mirror manually:
echo   1. Open Docker Desktop
echo   2. Settings -^> Docker Engine
echo   3. Add registry-mirrors to JSON
echo   4. Apply and Restart
echo.
echo See docker-daemon.json for example config
echo.
pause

docker-compose pull

echo Step 4/5: Building server image...
docker-compose build

echo Step 5/5: Starting services...
docker-compose down
docker-compose up -d

echo.
timeout /t 10 /nobreak >nul

echo Service status:
docker-compose ps

echo.
echo Testing health endpoint...
curl -s http://localhost:8080/health

echo.
echo ========================================
echo Done! Check status above.
echo ========================================
echo.
echo API: http://localhost:8080/api/v1
echo Swagger: http://localhost:8080/swagger/index.html
echo MinIO: http://localhost:9001
echo.
pause