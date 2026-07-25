# tools/slice.ps1
# Reads Intel HEX, pads to 48KB in memory, and slices into 4KB MAME ROMs.

$inputFile = "src\zout\Gorf_Disassembly.hex"
$outputDir = "roms"

if (-not (Test-Path $inputFile)) {
    Write-Error "Input HEX file '$inputFile' not found!"
    exit 1
}

if (-not (Test-Path $outputDir)) {
    New-Item -ItemType Directory -Force -Path $outputDir | Out-Null
}

# Step 1: Create a 48KB (0xC000) canvas pre-loaded with 0xFF padding
$memory = [byte[]]::new(0xC000)
for ($i = 0; $i -lt 0xC000; $i++) { $memory[$i] = 0xFF }

# Step 2: Parse the Intel HEX file and paint the data
$hexLines = Get-Content $inputFile
foreach ($line in $hexLines) {
    if (-not $line.StartsWith(":")) { continue }

    $byteCount = [Convert]::ToByte($line.Substring(1, 2), 16)
    $address   = [Convert]::ToUInt16($line.Substring(3, 4), 16)
    $recordType= [Convert]::ToByte($line.Substring(7, 2), 16)

    # Record Type 00 = Data Record
    if ($recordType -eq 0) {
        for ($i = 0; $i -lt $byteCount; $i++) {
            $dataByte = [Convert]::ToByte($line.Substring(9 + ($i * 2), 2), 16)
            $targetAddr = $address + $i
            if ($targetAddr -lt 0xC000) {
                $memory[$targetAddr] = $dataByte
            }
        }
    }
}

# Step 3: Define 4KB ROM chip slice maps targeting the correct addresses
$romMap = [ordered]@{
    "gorf-a.bin" = 0x0000..0x0FFF
    "gorf-b.bin" = 0x1000..0x1FFF
    "gorf-c.bin" = 0x2000..0x2FFF
    "gorf-d.bin" = 0x3000..0x3FFF
    "gorf-e.bin" = 0x8000..0x8FFF
    "gorf-f.bin" = 0x9000..0x9FFF
    "gorf-g.bin" = 0xA000..0xAFFF
    "gorf-h.bin" = 0xB000..0xBFFF
}

Write-Host "Slicing memory canvas into MAME ROMs..."
foreach ($romName in $romMap.Keys) {
    $range = $romMap[$romName]
    $slice = $memory[$range]
    $outPath = Join-Path $outputDir $romName
    [System.IO.File]::WriteAllBytes($outPath, $slice)
    Write-Host "  -> Wrote $romName ($($slice.Length) bytes)"
}
Write-Host "Done!"