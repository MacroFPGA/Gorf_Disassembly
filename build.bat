@echo off
setlocal

cd /d "%~dp0"

set "BUILD_GERMAN=0"
if /i "%~1"=="-g" set "BUILD_GERMAN=1"

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

if "%BUILD_GERMAN%"=="1" (
    if not exist "src\german\GERMAN_X11.asm" (
        echo ERROR: German source file not found: src\german\GERMAN_X11.asm
        pause
        exit /b 1
    )

    echo [2.5/4] Assembling Optional German ROM: GERMAN_X11.asm
    "%ZMAC_BIN%" -h -o src\zout\GERMAN_X11.hex -x src\zout\GERMAN_X11.lst src\german\GERMAN_X11.asm
    if errorlevel 1 (
        echo ERROR: zmac failed while assembling the German ROM.
        pause
        exit /b 1
    )

    powershell -NoProfile -ExecutionPolicy Bypass -Command ^
        "$inputFile = 'src\zout\GERMAN_X11.hex';" ^
        "$outputFile = 'roms\german.x11';" ^
        "if (-not (Test-Path $inputFile)) { Write-Error 'German HEX file missing.'; exit 1 };" ^
        "$memory = [byte[]]::new(0x1000);" ^
        "for ($i = 0; $i -lt 0x1000; $i++) { $memory[$i] = 0xFF };" ^
        "$written = 0;" ^
        "$hexLines = Get-Content $inputFile;" ^
        "foreach ($line in $hexLines) {" ^
        "    if (-not $line.StartsWith(':')) { continue };" ^
        "    $byteCount = [Convert]::ToByte($line.Substring(1, 2), 16);" ^
        "    $address = [Convert]::ToUInt16($line.Substring(3, 4), 16);" ^
        "    $recordType = [Convert]::ToByte($line.Substring(7, 2), 16);" ^
        "    if ($recordType -eq 0) {" ^
        "        for ($i = 0; $i -lt $byteCount; $i++) {" ^
        "            $targetAddr = $address + $i;" ^
        "            if (($targetAddr -ge 0xC000) -and ($targetAddr -lt 0xD000)) {" ^
        "                $memory[$targetAddr - 0xC000] = [Convert]::ToByte($line.Substring(9 + ($i * 2), 2), 16);" ^
        "                $written++;" ^
        "            }" ^
        "        }" ^
        "    }" ^
        "};" ^
        "if ($written -ne 0x1000) { Write-Error ('German ROM contains ' + $written + ' assembled bytes; expected 4096.'); exit 1 };" ^
        "[System.IO.File]::WriteAllBytes($outputFile, $memory);" ^
        "Write-Host ('  -> Wrote german.x11 (' + $memory.Length + ' bytes)');"

    if errorlevel 1 (
        echo ERROR: German ROM conversion failed.
        pause
        exit /b 1
    )
)

echo [3/4] Splitting image into Gorf ROMs...
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "$inputFile = 'src\zout\Gorf_Disassembly.hex';" ^
    "$outputDir = 'roms';" ^
    "if (-not (Test-Path $inputFile)) { Write-Error 'Input HEX file missing.'; exit 1 };" ^
    "$memory = [byte[]]::new(0xC000);" ^
    "for ($i = 0; $i -lt 0xC000; $i++) { $memory[$i] = 0xFF };" ^
    "$hexLines = Get-Content $inputFile;" ^
    "foreach ($line in $hexLines) {" ^
    "    if (-not $line.StartsWith(':')) { continue };" ^
    "    $byteCount = [Convert]::ToByte($line.Substring(1, 2), 16);" ^
    "    $address   = [Convert]::ToUInt16($line.Substring(3, 4), 16);" ^
    "    $recordType= [Convert]::ToByte($line.Substring(7, 2), 16);" ^
    "    if ($recordType -eq 0) {" ^
    "        for ($i = 0; $i -lt $byteCount; $i++) {" ^
    "            $dataByte = [Convert]::ToByte($line.Substring(9 + ($i * 2), 2), 16);" ^
    "            $targetAddr = $address + $i;" ^
    "            if ($targetAddr -lt 0xC000) { $memory[$targetAddr] = $dataByte };" ^
    "        }" ^
    "    }" ^
    "};" ^
    "if ($env:BUILD_GERMAN -eq '1') {" ^
    "    $romMap = [ordered]@{" ^
    "        '873a.x1' = 0x0000..0x0FFF; '873b.x2' = 0x1000..0x1FFF;" ^
    "        '873c.x3' = 0x2000..0x2FFF; '873d.x4' = 0x3000..0x3FFF;" ^
    "        '873e.x5' = 0x8000..0x8FFF; '873f.x6' = 0x9000..0x9FFF;" ^
    "        '873g.x7' = 0xA000..0xAFFF; '873h.x8' = 0xB000..0xBFFF;" ^
    "    };" ^
    "} else {" ^
    "    $romMap = [ordered]@{" ^
    "        'gorf-a.bin' = 0x0000..0x0FFF; 'gorf-b.bin' = 0x1000..0x1FFF;" ^
    "        'gorf-c.bin' = 0x2000..0x2FFF; 'gorf-d.bin' = 0x3000..0x3FFF;" ^
    "        'gorf-e.bin' = 0x8000..0x8FFF; 'gorf-f.bin' = 0x9000..0x9FFF;" ^
    "        'gorf-g.bin' = 0xA000..0xAFFF; 'gorf-h.bin' = 0xB000..0xBFFF;" ^
    "    };" ^
    "};" ^
    "foreach ($romName in $romMap.Keys) {" ^
    "    $slice = $memory[$romMap[$romName]];" ^
    "    [System.IO.File]::WriteAllBytes((Join-Path $outputDir $romName), $slice);" ^
    "    Write-Host ('  -> Wrote ' + $romName + ' (' + $slice.Length + ' bytes)');" ^
    "}"

if %ERRORLEVEL% neq 0 (
    echo ERROR: ROM slicing failed.
    pause
    exit /b %ERRORLEVEL%
)

if "%BUILD_GERMAN%"=="1" (
    echo [4/4] Packaging roms\gorfpgm1g.zip...
    powershell -NoProfile -ExecutionPolicy Bypass -Command ^
        "$romFiles = Get-ChildItem -Path 'roms\873?.x?';" ^
        "if ($romFiles.Count -ne 8) { Write-Error 'Expected eight Program-2 CPU ROM files.'; exit 1 };" ^
        "$romFiles += Get-Item 'roms\german.x11';" ^
        "if (Test-Path 'roms\sc01.bin') { $romFiles += Get-Item 'roms\sc01.bin' };" ^
        "Compress-Archive -Path $romFiles.FullName -DestinationPath 'roms\gorfpgm1g.zip' -Force"
) else (
    echo [4/4] Packaging roms\gorf.zip...
    powershell -NoProfile -ExecutionPolicy Bypass -Command ^
        "$romFiles = Get-ChildItem -Path 'roms\gorf-?.bin';" ^
        "if (Test-Path 'roms\sc01.bin') { $romFiles += Get-Item 'roms\sc01.bin' };" ^
        "Compress-Archive -Path $romFiles.FullName -DestinationPath 'roms\gorf.zip' -Force"
)

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
