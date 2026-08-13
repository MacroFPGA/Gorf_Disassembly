# Gorf Runtime Monitor

Version 2.3.1

Gorf Monitor is a MAME Lua debugging HUD for examining *Gorf* while it runs.
It monitors game variables, Votrax SC-01 speech, both Astrocade sound chips,
video and palette registers, and TERSE execution.

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
| `gti()` | Important | Compact game, speech, music, and TERSE summary |
| `gtg()` | Game | Game variables, mission and rank names, players, scores, and credits |
| `gtau()` | Audio | Votrax, both music engines, both sound chips, and recent audio history |
| `gtt()` | TERSE | Live dispatches, target decoding, and typed IX frames |
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

Music `LAST EXEC` entries are captured after the native interpreter fetches an
opcode. `NEXT PTR` samples the engine's program pointer; it does not identify an
executed byte.

`RECENT AUDIO EXEC / I/O` retains the last ten observed music-opcode executions
and Astrocade sound-chip writes. Sound entries include the chip, raw port and
value, decoded register name, and source PC.

## TERSE view

The TERSE execution engine is Gorf's internal threaded interpreter. The monitor
records a dispatch only when the Z80 reaches `$0060`, after `DSPATCH` has loaded
the target into `HL` and advanced `BC` past the two-byte threaded cell.

`SP`, `IX`, `IY`, `BC`, and `PC` are captured at the same dispatch. They are not
live-register samples taken when the HUD redraws.

Each dispatch uses this format:

```text
STREAM $BC69 -> $BB7E
ENTER -> $B32C W_B5D1 [ASM]
CTX W_B5D1 +$08
```

Decoded elements:

- `STREAM source -> target` is the address of the current threaded cell and the
  address fetched from that cell.
- `ENTER -> first-target` means the target begins with `_ENTER` (`$CF`). The
  following word is the first threaded target, not a `RST $08` destination.
- `BYTES xx xx xx` is a raw preview of a native target. Individual byte values
  are never treated as symbol addresses.
- `CTX name +offset` is the containing TERSE entry and current stream offset.
- IX is a shared return/control stack. Colon definitions store call
  continuations, `DO` stores three-cell loop frames, and `>R` stores data until
  `R>` retrieves it.
- Frames are reported as `CALL`, `LOOP`, `DATA`, or `UNKNOWN`, youngest first.
  Calls and loop triples are structurally checked. `DATA` requires an observed
  `>R`.
- A cell present when tracing starts remains `UNKNOWN` unless its call or loop
  structure can be verified. Unknown cells do not create named call frames or
  change caller context.
- A pre-capture call can be recovered when its saved continuation follows a
  threaded target beginning with `_ENTER`. It is recorded as a `structural`
  call.

### Reconstructing TERSE

Runtime traces can validate a reconstructed TERSE program, but they cover only
the paths executed during the capture. Complete reconstruction also requires
static analysis.

A reconstruction should:

1. Parse colon bodies, inline operands, and exact symbols from the ROM, LST, and
   original source blocks.
2. Record word boundaries, literals, branches, calls, loops, and unresolved
   native words without losing address information.
3. Use dispatch traces to measure coverage and verify BC, SP, IX, control flow,
   and dynamic calls.
4. Model native graphics, sound, protected RAM, and hardware words only after
   their behavior is confirmed.
5. Generate address-annotated TERSE source from the verified model.

Compiled bytes cannot reveal original comments, spelling, or which equivalent
source form was used.

## Reverse engineering and discoveries

The default `unknown` mode prints one console line for a target with no exact
symbol or annotation. Quarantined hypotheses remain visible as `HYP` in the HUD
without filling the console.

Discovery logging can be changed at runtime:

```lua
GorfMonitor.discovery("unknown") -- completely unknown targets only (default)
GorfMonitor.discovery("all")     -- unknown targets and hypotheses
GorfMonitor.discovery("off")     -- no discovery console output
```

In `all` mode an annotated candidate is identified as `[HYPOTHESIS]`, not
`[DISCOVERY]`. `GorfMonitor.reset_trace()` clears per-target deduplication.

### Mapping new words

1. Run through game states or missions and capture an unknown target:

   ```text
   [DISCOVERY] IP: $BB7F -> Target: $B32C | ENTER -> $006D _LIT (Context: W_BB7E)
   ```
2. Inspect the address in `Gorf_Disassembly.asm`. Add a neutral label after the
   boundary is structurally confirmed. Use a semantic name only when its
   meaning is supported by source or runtime evidence.
3. Reassemble and verify that the output ROM hashes are unchanged.
4. Type `gtl()` in the MAME console to replace the current imported symbol set
   with the newly assembled LST. Lua table edits require reloading the monitor;
   `gtl()` reloads the listing, not Lua modules.

Do not add guessed routines to `D.entries` or `D.symbols`. Use `D.entries` for
confirmed high-level TERSE entry points and `D.symbols` for exact ASM labels.
Put behavioral candidates in `D.annotations` with an explicit confidence.

## Load LST symbols

To import labels from the default listing:

```lua
gtl()
```

The default path is:

```text
src/zout/Gorf_Disassembly.lst
```

An alternate path may be supplied on Linux or Windows:

```lua
gtl("/home/user/gorf/src/zout/Gorf_Disassembly.lst")
gtl("C:/gorf/src/zout/Gorf_Disassembly.lst")
gtl([[C:\gorf\src\zout\Gorf_Disassembly.lst]])
```

The loader reads labels and EQU symbols from the listing body and merges zmac's
final symbol table when present. It supports older and newer LST layouts,
address-only labels, and aliases. Source definitions take priority when several
labels share an address. Otherwise, an existing exact ASM name is retained when
it is one of the aliases.

The LST overrides the embedded fallback when they disagree. The console reports
loaded addresses, aliases, confirmed fallback names, and superseded names. If
no labels are recognized, the previous imported set is retained.

## Video palette

`gtv()` displays the eight Astrocade color registers and draws a swatch for
every value observed since the monitor loaded:

- Left side of the color boundary: ports `$04-$07`, pixels 0-3
- Right side of the color boundary: ports `$00-$03`, pixels 0-3

Swatches use MAME's live screen palette. An unobserved register is shown as
`--` with no swatch, distinguishing it from an observed `$00` write.

## Data labels

| Label | Meaning |
| --- | --- |
| Raw hexadecimal value | Direct register, RAM, or observed I/O value |
| `ASM` | Exact address match in the monitor's source-derived fallback symbols |
| `LST` | Exact address match imported from a listing file |
| `NOTE` | Behavioral annotation kept separate from exact symbols |
| `HYP` | Explicitly unverified behavioral annotation |
| `CTX` | Context or depth reconstructed from dispatch and physical stack data |
| `TERSE_$xxxx` / `NATIVE_$xxxx` | Neutral name because no exact symbol is available |
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
GorfMonitor.save_discovery_emissions("discovery_audit.csv")
GorfMonitor.discovery("unknown")
GorfMonitor.version_info()
GorfMonitor.load_test()

GorfMonitor.font_scale(1)
GorfMonitor.refresh_rate(5)
GorfMonitor.visible(true)
GorfMonitor.freeze(true)
GorfMonitor.auto_place(true)
GorfMonitor.set_region(0.770, 0.010, 0.995, 0.570)
GorfMonitor.stop()
```

Relative export paths use MAME's current working directory. The argument-free
`gtl()` command is the exception; it resolves from the entry script's directory.

`GorfMonitor.freeze(true)` freezes the HUD image, not Gorf or the dispatcher
instrumentation. Tracing continues in the background. Use
`GorfMonitor.freeze(false)` to resume live display. The normal trace buffer
holds 32,768 dispatches; the guided runner expands it to 131,072.

## Guided test runner

Load the matching runner with:

```lua
gmts()
```

The runner controls MAME without debugger F5/F11 interaction. Use `gtrun()`,
`gtpause()`, and `gtack()` as prompted. `gtskip(N)` skips forward to test N. To
run only the return-stack test, enter `gtskip(6)`.

Test 6 checks IX reconstruction when capture begins inside an active TERSE
chain. It reports structural call recovery, unknown depth, and any observed
`GNAME`, `>R`, or `R>` activity. A title transition alone does not prove that
the optional `_GNAME` path executed.

## Mission modules and X11

Each mission ROM begins with a five-byte module header: marker `$A5`, a gameplay
TERSE entry pointer, and an attract-mode entry pointer. `MISSION_MODULE_TABLE`
at `$B2E7` lists Astro Battles, Laser Attack, Galaxians, Space Warp, and Flag
Ship. The ASM uses labels for these bytes without changing the ROM image.

SETTINGS bit 3 selects the resident speech path or the foreign X11 provider at
`$C000`. Its length-prefixed message table begins at `$C003`. Keep X11 labels in
provider-specific mappings; do not add them to resident TERSE entries without
an exact X11 disassembly and ROM identity.

## Rendering and placement

The monitor detects the right edge of the game screen and the top of the Space
Rank artwork. Its fallback region is `(0.770, 0.010)` through `(0.995, 0.570)`
in normalized full-window coordinates.

## Troubleshooting

If the monitor loads but no HUD appears, run:

```lua
GorfMonitor.status()
```

Confirm that `HUD callback` is `frame_done` and that `HUD draws` increases. The
selected MAME artwork view must also contain the Space Rank board.
