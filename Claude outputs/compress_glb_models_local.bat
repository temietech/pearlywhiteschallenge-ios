@echo off
REM GLB Compression Script for Windows - Uses locally installed packages
REM SETUP: Run setup_compression.bat first
REM USAGE: Double-click this file, or run from command line

setlocal enabledelayedexpansion

REM Get the script's directory
set SCRIPT_DIR=%~dp0

REM Update this to your actual project path
set ASSETS_PATH=C:\Users\temie\Documents\Personal Life\Pearly White\Challenge\App\Pearly Whites Challenge\assets

REM If assets not found at expected location, prompt user
if not exist "%ASSETS_PATH%" (
    echo.
    echo ERROR: Could not find assets folder at: %ASSETS_PATH%
    echo.
    echo Please update the ASSETS_PATH in this script to point to your assets folder.
    echo.
    pause
    exit /b 1
)

echo.
echo ====================================================================
echo GLB Model Compression Tool (Draco Compression - Local Packages)
echo ====================================================================
echo.
echo Target folder: %ASSETS_PATH%
echo.

REM Check if node_modules exists
if not exist "%SCRIPT_DIR%node_modules" (
    echo ERROR: node_modules not found!
    echo.
    echo Please run setup_compression.bat first to install dependencies.
    echo.
    pause
    exit /b 1
)

echo Starting compression... This may take several minutes.
echo.

cd /d "%SCRIPT_DIR%"
node "%SCRIPT_DIR%compress_glb_local.js" "%ASSETS_PATH%"

echo.
echo Done! Press any key to close this window.
pause
