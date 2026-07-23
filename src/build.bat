@echo off
echo Compiling Gorf_Disassembly...

:: Run zmac targeting Intel HEX (-o) and Listing (-x) output
..\tools\zmac.exe -h -o Gorf_Disassembly.hex -x Gorf_Disassembly.lst Gorf_Disassembly.asm

:: Check if the compilation produced a hex file successfully
IF NOT EXIST "Gorf_Disassembly.hex" (
    echo [ERROR] zmac failed to generate the hex file.
    pause
    exit /b
)

:: Run the PowerShell slicing script
echo Padding and slicing binary...
powershell.exe -ExecutionPolicy Bypass -File "..\tools\slice.ps1"

echo.
echo Build complete! ROMs are located in the \roms directory.
pause