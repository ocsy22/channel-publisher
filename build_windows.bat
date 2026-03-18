@echo off
chcp 65001 >nul
echo ================================================
echo   Channel Publisher - Windows 一键构建脚本
echo ================================================
echo.

REM 检查 Flutter 是否安装
where flutter >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo [错误] 未检测到 Flutter！
    echo.
    echo 请先安装 Flutter：
    echo   1. 访问 https://flutter.dev/docs/get-started/install/windows
    echo   2. 下载并解压 Flutter SDK
    echo   3. 将 flutter\bin 添加到系统 PATH 环境变量
    echo.
    pause
    exit /b 1
)

REM 检查 Visual Studio
where cl >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo [警告] 未检测到 Visual Studio C++ 编译工具
    echo 请确保已安装 Visual Studio 2022 with C++ Desktop Workload
    echo 下载地址: https://visualstudio.microsoft.com/downloads/
    echo.
)

echo [1/4] 启用 Windows 桌面支持...
flutter config --enable-windows-desktop
echo.

echo [2/4] 安装依赖包...
flutter pub get
if %ERRORLEVEL% NEQ 0 (
    echo [错误] 依赖安装失败，请检查网络连接
    pause
    exit /b 1
)
echo.

echo [3/4] 构建 Windows Release 版本...
echo 这可能需要 3-5 分钟，请耐心等待...
flutter build windows --release
if %ERRORLEVEL% NEQ 0 (
    echo [错误] 构建失败！请检查以上错误信息
    pause
    exit /b 1
)
echo.

echo [4/4] 构建完成！
echo.
echo ================================================
echo   EXE 文件位置:
echo   build\windows\x64\runner\Release\
echo   文件名: channel_publisher.exe
echo ================================================
echo.

set BUILD_DIR=build\windows\x64\runner\Release
if exist "%BUILD_DIR%\channel_publisher.exe" (
    echo [成功] 找到可执行文件！
    echo 路径: %CD%\%BUILD_DIR%\channel_publisher.exe
    echo.
    set /p OPEN_DIR="是否打开输出目录？(y/n): "
    if /i "%OPEN_DIR%"=="y" (
        explorer "%BUILD_DIR%"
    )
) else (
    echo [提示] 请在 build\windows 目录中查找生成的文件
)

echo.
echo 按任意键退出...
pause >nul
