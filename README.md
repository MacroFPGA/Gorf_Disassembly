# Gorf — Z80 Source Reconstruction

This repository contains the disassembly, source code reconstruction, and technical documentation for the classic arcade game **Gorf** (Midway, 1981).

The goal of this project is to produce an accurate, buildable Z80 assembly codebase for preservation, study, and reverse engineering, preserving historical TERSE context while adhering to modern readability standards.

---

## 🛠️ Build & Tools

* **Assembler:** [zmac v1.3](https://ballyalley.com/ml/ml_tools/Zmac13_win32.zip) (Z80 Macro Cross Assembler)
* **Primary Source:** `src/Gorf_Disassembly.asm`

### Building the ROMs — Windows 10 / 11

To assemble the source code into MAME-ready ROMs, navigate to the `src/` directory and run the Windows build script:

```cmd
cd src
build.bat
```
The script will automatically compile the assembly and deposit the final, ready-to-play binaries (`gorf-a.bin` through `gorf-h.bin`) into a new `roms/` folder in your project root.

### Building the ROMs — Linux

The Linux build requires Bash, `zip`, and a Linux build of `zmac`. The build script searches for `zmac` in the following order:

1. The executable named by the `ZMAC` environment variable.
2. `tools/zmac` in the repository.
3. `zmac` in `PATH`.

From the `src/` directory, make the script executable once and run it:

```bash
cd src
chmod +x build.sh
./build.sh
```

To select a specific assembler executable:

```bash
ZMAC=/path/to/zmac ./build.sh
```

The script will automatically compile the assembly and deposit the final, ready-to-play binaries (`gorf-a.bin` through `gorf-h.bin`) and the packaged gorf.zip into the `roms/` folder in your project root.

#### Optional SC-01 speech ROM

The SC-01 speech ROM is not part of the reconstructed program source. If a file named `sc01.bin` exists in `src/`, the Linux build automatically includes it in `roms/gorf.zip`. If the file is absent, the build continues and packages only the eight Gorf program ROMs.

---

## 📁 Repository Structure

```text
├── src/                    # Z80 source and platform build scripts
│   ├── Gorf_Disassembly.asm
│   ├── build.bat
│   └── build.sh
├── tools/                  # Build helpers and assembler binaries
│   ├── slice.ps1           # Windows Intel HEX-to-ROM slicing script
│   └── zmac.exe            # Windows Z80 Macro Cross Assembler
├── roms/                   # Generated Gorf ROM images and gorf.zip
├── Docs/                   # Technical references and game information
│   ├── Z80_Coding_Style.md
│   └── TERSE_Naming_Rules.md
└── README.md               # Game-specific overview (this file)
```

---

## 📖 Coding Standards & Guidelines

To maintain visual and structural consistency across all arcade disassembly repositories, source code edits should follow our shared project standards.

| 🚨 A Note on Flexibility |
| :--- |
| **These formatting standards are meant for guidance, not to force you into a coding straitjacket.** While a consistent layout is highly encouraged as a best practice, you are free to make exceptions without consequence. If adhering to these specific columns compromises the readability of a complex routine or data block, or you just don't like the look of the code, take the liberty to break the rule. **Readability and accuracy always come first.** |

* **Z80 Coding Style & Layout** — Column alignments, spacing, and comment conventions.
* **TERSE Naming Rules** — Capitalization, label length, and internal jump conventions.
