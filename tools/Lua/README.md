<!-- GORF_MONITOR.md -->

# Gorf Runtime Monitor

Version 2.0.0

Gorf Monitor is a MAME Lua debugging HUD for examining *Gorf* program while it runs. It monitors game variables, Votrax SC-01 speech, both Astrocade sound chips, video and palette
registers, and TERSE execution.

The monitor does not modify the ROM.

## Start MAME

From the repository root:

```bash
mame -console -window -skip_gameinfo -rompath roms/ \
  -autoboot_script ./tools/Lua/gorf_monitor.lua gorf
```

The Lua console is ready when MAME displays `[MAME]>`. 

## HUD views

The `all` view opens by default.

| Shortcut | View | Contents |
| --- | --- | --- |
| `gtg()` | Game | Game variables, mission and rank names, players, scores, and credits |
| `gtau()` | Audio | Votrax, both music engines, both sound chips, and recent audio history |
| `gtt()` | TERSE | Live dispatches, instruction/bytecode parsing logs, reconstructed stacks, and parent macro tracking |
| `gtv()` | Video | Video ports, palette values and swatches, pattern-board ports, and recent I/O |
| `gta()` | All | Combined default view |
| `gtp()` | Next | Advance to the next view |

## Game values

The monitor displays the game-owned values individually. It does not create an
aggregate game state such as `STARTING` or `GAME ACTIVE`.

- `DEMOMODE` is the game's game-over/demo flag.
- `MISSION` is the current mission byte; its decoded mission name appears beside
  the raw value.
- `COINSIN` at `$D003` is the whole-credit balance.
- `COINFRAC` at `$D002` is the fractional-credit accumulator.
- `COINS?` at `$D009` is the transient coin-event flag, not the credit balance.
- Mission and rank names are always displayed beside their raw bytes.

## Speech and audio

The Votrax fields have separate meanings:

- `SPEAKING` is assembled from phonemes observed at Gorf's SC-01 transfer path.
- `LAST SPOKEN` is the most recently completed observed utterance.
- `QUEUED` is decoded from the current speech-queue slot and is not presented as
  spoken.
- `RECENT SPOKEN (OBSERVED)` retains the last eight completed utterances.

Music `LAST EXEC` entries are captured at the native music interpreter after an
opcode is fetched. `NEXT PTR` is a separate sample of the engine's program
pointer and does not claim that the sampled byte executed.

`RECENT AUDIO EXEC / I/O` retains the last ten observed music-opcode executions
and Astrocade sound-chip writes. Sound entries include the chip, raw port and
value, decoded register name, and source PC.

## TERSE View
The **TERSE execution engine** acts as an internal Virtual Machine running custom threaded macro words. The `RECENT DISPATCHES` log uses inline live memory parsing to map exact bytecode execution flows. 

Every dispatch log displays engine context in the following multi-line format:
```text
STREAM $BC69 -> $BB7E
[RST08 -> $B32C] _W_B5D1 [TERSE WORD]
RECON UNKNOWN TERSE WORD +#08
```

### Decoded Elements
- **`STREAM [Addr1] -> [Addr2]`**: Indicates the Threaded Interpretive Code program counter instruction pointer (`IP`) moving to an active execution target address.
- **`[RST08 -> Destination]` / `[B0 B1 B2]`**: A real-time raw byte extraction from the target address. 
  - If the initial byte is native machine code, it prints the three raw bytes (e.g., `[$D9 $01 $16]`). Known primitive labels replace hex bytes where applicable.
  - If the initial byte is `$CF` (`rst $08`), the engine automatically processes a **16-bit Little-Endian pointer calculation**, combining the subsequent byte pair into a direct destination jump address. If that calculated address matches a name in the symbol table, the label prints instead of raw hex (e.g., `[RST08 -> _LITbyte]`).
- **`RECON [Name] +[Offset]`**: The monitor automatically reconstructs the call stack and tracks how many bytes deep (`+#08`) execution has traveled relative to the parent macro definition block.

## Reverse Engineering & Discoveries
Unmapped execution paths trigger automated, single-instance discovery logs in the terminal output. Historical deduplication ensures that an unknown address is logged exactly once per emulator session to prevent console flooding.

### Mapping New Words
1. Run through game states or missions and look for uniquely logged terminal discoveries:
   ```text
   [DISCOVERY] IP: BB7F -> Target: B32C | [RST08 -> _DI] (Context: UNKNOWN TERSE WORD)
   ```
2. Note the unmapped target address (`$B32C`) and see where it cascades. In the example above, the macro wraps a native system disable-interrupts routine (`_DI`).
3. Open `tools/Lua/gorf_monitor_data.lua` file.
4. Inject discovered hex assignment into the central `D.symbols` lookup table, sorting it numerically to maintain  workspace structure:
   ```lua
   D.symbols = {
       -- ...
       [0xB32C] = "GAME_CREDIT_CHECK_LOOP",  -- Loops to verify coin/fraction flags
       -- ...
   }
   ```
5. Type `gtl()` inside the interactive MAME console prompt to reload symbols without dropping current game or emulator execution frame.

## Load LST symbols

To import labels from the default listing:

```lua
gtl()
```

which by default looks for the LST file at:
```text
src/zout/Gorf_Disassembly.lst
```

An alternate path may be supplied on Linux or Windows:

```lua
gtl("/home/user/gorf/src/zout/Gorf_Disassembly.lst")
gtl("C:/gorf/src/zout/Gorf_Disassembly.lst")
gtl([[C:\gorf\src\zout\Gorf_Disassembly.lst]])
```

Importing runs once per command. Exact labels are added without replacing built-in names. The console reports imported labels, existing labels, and conflicts. An unlabeled routine remains unknown.

## Video palette

`gtv()` displays the eight Astrocade color registers and draws a swatch for every value observed since the monitor loaded:

- Left side of the color boundary: ports `$04-$07`, pixels 0-3
- Right side of the color boundary: ports `$00-$03`, pixels 0-3

Swatches use MAME's live screen palette. A register that has not been observed is shown as `--` and has no swatch. This distinguishes an unknown value from an observed `$00` write.

## Data labels

| Label | Meaning |
| --- | --- |
| Raw hexadecimal value | Direct register, RAM, or observed I/O value |
| `BUILT-IN` | Exact address match in the monitor's symbol table |
| `LST` | Exact address match imported from a listing file |
| `DECODED` | Description derived from a known routine or hardware definition |
| `RECON` | Context, call stack, or depth reconstructed from observed execution |
| `UNKNOWN` | No exact symbol is available |
| `--` | The value has not been observed or is unavailable |

## Full console commands

```lua
GorfMonitor.help()
GorfMonitor.status()

GorfMonitor.show_important()
GorfMonitor.show_game()
GorfMonitor.show_audio()
GorfMonitor.show_terse()
GorfMonitor.show_video()
GorfMonitor.show_all()
GorfMonitor.page("game")
GorfMonitor.next_page()

GorfMonitor.dump(30)
GorfMonitor.hot(20)
GorfMonitor.unknown(20)
GorfMonitor.reset_trace()

GorfMonitor.save_trace("gorf_trace.csv")
GorfMonitor.save_trace("gorf_trace.csv", 200)
GorfMonitor.save_discovery("new_terse_targets.asm")

GorfMonitor.font_scale(1)
GorfMonitor.refresh_rate(5)
GorfMonitor.visible(true)
GorfMonitor.auto_place(true)
GorfMonitor.set_region(0.770, 0.010, 0.995, 0.570)
GorfMonitor.stop()
```

Relative export paths use MAME's current working directory. The argument-free
`gtl()` command is the exception; it resolves from the entry script's directory.

## Rendering and placement

The monitor detects the right edge of the game screen and the top of the Space Rank artwork. Its fallback region is `(0.770, 0.010)` through `(0.995, 0.570)` in normalized full-window coordinates.

## Troubleshooting

If the monitor loads but no HUD appears, run:

```lua
GorfMonitor.status()
```

Confirm that `HUD callback` is `frame_done` and that `HUD draws` increases. Also confirm that the selected MAME artwork view contains the Space Rank board.

