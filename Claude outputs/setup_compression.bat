@echo off
REM Setup script for GLB compression - installs packages locally
REM Run this FIRST before running the compression script

echo.
echo ====================================================================
echo GLB Compression Setup - Installing Node.js dependencies locally
echo ====================================================================
echo.

REM Get the script's directory
set SCRIPT_DIR=%~dp0

echo Setting up packages in: %SCRIPT_DIR%
echo.

REM Check if Node.js is installed
where /q node
if errorlevel 1 (
    echo ERROR: Node.js is not installed!
    echo Please install Node.js from https://nodejs.org (LTS version)
    echo.
    pause
    exit /b 1
)

echo Node.js found. Installing gltf-transform packages locally...
echo.

REM Install packages locally (not globally) in the script directory
cd /d "%SCRIPT_DIR%"
call npm install @gltf-transform/core @gltf-transform/extensions

if errorlevel 1 (
    echo.
    echo ERROR: Failed to install packages
    echo.
    pause
    exit /b 1
)

echo.
echo ====================================================================
echo Setup complete! Packages installed successfully.
echo.
echo You can now run: compress_glb_models_local.bat
echo ====================================================================
echo.
pause
