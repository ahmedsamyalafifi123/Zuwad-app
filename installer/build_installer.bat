@echo off
echo ==========================================
echo   Zuwad Academy Installer Builder
echo ==========================================
echo.

REM Check if ISCC is available
where iscc >nul 2>nul
if %ERRORLEVEL% neq 0 (
    echo ERROR: Inno Setup Compiler (iscc.exe) not found in PATH!
    echo.
    echo Please add Inno Setup to your PATH:
    echo   setx PATH "%PATH%;C:\Program Files (x86)\Inno Setup 6"
    echo.
    echo Or run this script from Inno Setup folder.
    pause
    exit /b 1
)

echo Step 1: Building Flutter Windows Release...
cd ..
call flutter build windows --release
if %ERRORLEVEL% neq 0 (
    echo ERROR: Flutter build failed!
    pause
    exit /b 1
)

echo.
echo Step 2: Creating Installer...
cd installer
iscc zuwad_setup.iss

if %ERRORLEVEL% neq 0 (
    echo ERROR: Inno Setup compilation failed!
    pause
    exit /b 1
)

echo.
echo ==========================================
echo   SUCCESS! Installer created:
echo   installer\ZuwadSetup.exe
echo ==========================================
echo.
pause
