@echo off
chcp 65001 >nul
echo ========================================
echo 社交应用 Windows 客户端打包脚本
echo ========================================
echo.

REM 设置路径
set FLUTTER_PATH=C:\flutter
set PROJECT_DIR=%~dp0..
set CLIENT_DIR=%PROJECT_DIR%\client
set OUTPUT_DIR=%PROJECT_DIR%\release\windows

REM 检查 Flutter
if not exist "%FLUTTER_PATH%\bin\flutter.bat" (
    echo [错误] Flutter 未找到，请检查路径: %FLUTTER_PATH%
    pause
    exit /b 1
)

echo [1/5] 清理旧的构建文件...
if exist "%CLIENT_DIR%\build\windows" rmdir /s /q "%CLIENT_DIR%\build\windows"
if exist "%OUTPUT_DIR%" rmdir /s /q "%OUTPUT_DIR%"

echo [2/5] 获取依赖...
cd /d "%CLIENT_DIR%"
call "%FLUTTER_PATH%\bin\flutter.bat" pub get
if errorlevel 1 (
    echo [错误] 获取依赖失败
    pause
    exit /b 1
)

echo [3/5] 构建 Windows Release 版本...
call "%FLUTTER_PATH%\bin\flutter.bat" build windows --release
if errorlevel 1 (
    echo [错误] 构建失败
    pause
    exit /b 1
)

echo [4/5] 复制输出文件...
mkdir "%OUTPUT_DIR%"
xcopy /s /e /y "%CLIENT_DIR%\build\windows\x64\runner\Release\*" "%OUTPUT_DIR%\"

REM 复制必要的运行时
echo [5/5] 复制运行时依赖...
REM Flutter 已将所有依赖打包在 Release 目录中

REM 创建版本信息
echo 应用名称: 社交应用 > "%OUTPUT_DIR%\version.txt"
echo 版本: 1.0.0 >> "%OUTPUT_DIR%\version.txt"
echo 构建时间: %date% %time% >> "%OUTPUT_DIR%\version.txt"

echo.
echo ========================================
echo 构建完成!
echo 输出目录: %OUTPUT_DIR%
echo ========================================
echo.

REM 创建压缩包
set ZIP_FILE=%PROJECT_DIR%\release\SocialApp-Windows-x64.zip
if exist "%ZIP_FILE%" del "%ZIP_FILE%"
powershell Compress-Archive -Path "%OUTPUT_DIR%\*" -DestinationPath "%ZIP_FILE%" -Force
echo 压缩包: %ZIP_FILE%

pause