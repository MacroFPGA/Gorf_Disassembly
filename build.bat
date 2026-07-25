@echo off
setlocal enabledelayedexpansion

cd /d "%~dp0"

:: -----------------------------------------------------------------------------
:: Pre-flight Checks & Dependency Resolution
:: -----------------------------------------------------------------------------

:: Resolve zmac executable path
if defined ZMAC (
    if exist "%ZMAC%" (
        set "ZMAC_BIN=%ZMAC%"
    ) else (
        where "%ZMAC%" >nul 2>&1 && set "ZMAC_BIN=%ZMAC%" || (echo ERROR: ZMAC not found & pause & exit /b 1)
    )
) else if exist "tools\zmac.exe" (
    set "ZMAC_BIN=tools\zmac.exe"
) else (
    where zmac >nul 2>&1 && set "ZMAC_BIN=zmac" || (echo ERROR: zmac not found & pause & exit /b 1)
)

:: -----------------------------------------------------------------------------
:: Build Execution
:: -----------------------------------------------------------------------------

echo Gorf ROM build
echo   source: src\Gorf_Disassembly.asm
echo   output: roms
echo.

echo [1/4] Preparing clean build environment...
if exist "src\zout" rmdir /s /q "src\zout"
mkdir "src\zout"
if not exist "roms" mkdir "roms"

echo [2/4] Assembling Gorf_Disassembly.asm
echo       zmac: %ZMAC_BIN%
"%ZMAC_BIN%" -h -o src\zout\Gorf_Disassembly.hex -x src\zout\Gorf_Disassembly.lst src\Gorf_Disassembly.asm
if %ERRORLEVEL% neq 0 (
    echo ERROR: zmac failed. Review the assembler output above.
    pause
    exit /b %ERRORLEVEL%
)

echo [3/4] Splitting image into Gorf ROMs...
powershell -ExecutionPolicy Bypass -File tools\slice.ps1
if %ERRORLEVEL% neq 0 (
    echo ERROR: ROM slicing failed.
    pause
    exit /b %ERRORLEVEL%
)

echo [4/4] Packaging roms\gorf.zip...
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "$romFiles = Get-ChildItem -Path 'roms\gorf-?.bin';" ^
    "if (Test-Path 'roms\sc01.bin') { $romFiles += Get-Item 'roms\sc01.bin' };" ^
    "Compress-Archive -Path $romFiles.FullName -DestinationPath 'roms\gorf.zip' -Force"

if %ERRORLEVEL% neq 0 (
    echo ERROR: Packaging failed.
    pause
    exit /b %ERRORLEVEL%
)

echo.
echo =======================================================================
echo  BUILD SUCCESSFUL!
echo =======================================================================
pause