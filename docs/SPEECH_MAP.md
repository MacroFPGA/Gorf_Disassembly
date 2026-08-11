<!-- SPEECH_MAP.md -->
# Gorf Program 2 speech map

This document maps the English speech used by Gorf Program 2. It describes the resident Astrocade/SC-01 data and the game routines that select and combine it. 

## Speech path

The Astrocade sound system sends encoded phoneme commands to the SC-01 through I/O port `$17`. A speech record begins with a payload length followed by that many encoded bytes. Bits 0-5 select the SC-01 phoneme; bits 6-7 carry the game's inflection state and are part of the ROM data.

The Language DIP switch is read from port `$13`, bit `$08`. In English mode, the resident routine queues the requested record directly. In Foreign mode, it passes the resident record address in `DE` to the X11 entry at `$C000`, where the address is translated before it is queued.

The resident queue at `$D112-$D121` holds eight two-byte record pointers. Playback is interrupt-driven. This matters to translated speech because a compound line may enqueue several records while the SC-01 is still consuming an earlier one.

## English fragments

The fragment ID below is a documentation index for this map. Gorf itself identifies a fragment by its resident address, shown as the key. Payload counts exclude the leading length byte.

| ID | Source label | Resident key | English fragment | Bytes | Notes |
| ---: | --- | ---: | --- | ---: | --- |
| 0 | `SPK_INSERT` | `$115D` | Insert coin | 15 |  |
| 1 | `SPK_GORF` | `$116D` | I am the Gorfian Empire | 23 |  |
| 2 | `SPK_SPACE` | `$1185` | Space | 6 | Inserted before rank names |
| 3 | `SPK_CONQUER` | `$118C` | Gorfians conquer another galaxy | 27 |  |
| 4 | `SPK_TRY` | `$11A8` | Try again; I devour your coins | 30 |  |
| 5 | `SPK_LONG` | `$11C7` | Long live Gorf | 15 |  |
| 6 | `SPK_ROBOTS` | `$11D7` | Gorfian robots, attack! Attack! | 30 |  |
| 7 | `SPK_BADMOVE` | `$11F6` | Bad move | 9 |  |
| 8 | `SPK_HAHA` | `$1200` | Ha ha ha ha | 9 | Language-neutral laugh |
| 9 | `SPK_ESCAPE` | `$120A` | You cannot escape the Gorfian robots | 35 |  |
| 10 | `SPK_GOTYOU` | `$122E` | Got you | 8 |  |
| 11 | `SPK_NICE` | `$1237` | Nice shot | 11 |  |
| 12 | `SPK_TOOBAD` | `$1243` | Too bad | 7 |  |
| 13 | `SPK_PRIS` | `$124B` | Gorfians take no prisoners | 24 |  |
| 14 | `SPK_CADET` | `$1264` | Cadet | 6 |  |
| 15 | `SPK_CAPT` | `$126B` | Captain | 8 |  |
| 16 | `SPK_COLONEL` | `$1274` | Colonel | 6 |  |
| 17 | `SPK_GENERAL` | `$127B` | General | 8 |  |
| 18 | `SPK_WARRIOR` | `$1284` | Warrior | 8 |  |
| 19 | `SPK_AVENGER` | `$128D` | Avenger | 10 |  |
| 20 | `SPK_PROMOTE` | `$1298` | You have been promoted to | 25 |  |
| 21 | `SPK_SOME` | `$12B2` | Some galactic defender you are | 27 |  |
| 22 | `SPK_BITE` | `$12CE` | Bite the dust | 12 |  |
| 23 | `SPK_HAIL` | `$12DB` | All hail the supreme Gorfian Empire | 32 |  |
| 24 | `SPK_ENEMY` | `$12FC` | Another enemy ship destroyed | 26 |  |
| 25 | `SPK_BETCHA` | `$1317` | Your end draws near | 14 |  |
| 26 | `UNNAMED_A985` | `$A985` | Next time will be harder, but for now | 34 | Upper-ROM record; unnamed in the main disassembly |
| 27 | `UNNAMED_A9A8` | `$A9A8` | In the Gorfian chronicles | 24 | Upper-ROM record; unnamed in the main disassembly |
| 28 | `UNNAMED_A9C1` | `$A9C1` | For hitting my flagship | 21 | Upper-ROM record; unnamed in the main disassembly |
| 29 | `SPK_PUSH` | `$B3BE` | Push a player button | 21 |  |
| 30 | `SPK_DOOM` | `$B3D4` | You will meet a Gorfian doom | 26 |  |
| 31 | `SPK_SURVIVAL` | `$B3EF` | Survival is impossible | 21 |  |
| 32 | `SPK_ROBOWARRIOR` | `$B405` | Robot warriors, seek and destroy the | 32 |  |
| 33 | `SPK_GORFIAN` | `$B426` | My Gorfian robots are unbeatable | 34 |  |
| 34 | `SPK_IAM` | `$B449` | I am a Gorfian consciousness | 27 |  |
| 35 | `SPK_PREPARE` | `$B465` | Prepare yourself for annihilation | 30 |  |

## English phrase selection

Gorf does not have WoW's numeric phrase-ID table. The following rows enumerate the actual Program-2 selection tables and compound paths. `RANK` is one of `SPK_CADET`, `SPK_CAPT`, `SPK_COLONEL`, `SPK_GENERAL`, `SPK_WARRIOR`, or `SPK_AVENGER`; `_GETRANK` inserts `SPK_SPACE` immediately before it.

| Selector or path | Resident composition | English result | Notes |
| --- | --- | --- | --- |
| `phrases[0]` | `SPK_INSERT` | Insert coin | Attract table |
| `phrases[1]` | `SPK_GORF` | I am the Gorfian Empire | Attract table |
| `phrases[2]` | `SPK_LONG` | Long live Gorf | Attract table |
| `phrases[3]` | `SPK_INSERT` | Insert coin | Intentional duplicate |
| `SPKCOIN[0]` | `SPK_PUSH` | Push a player button | Coin/start prompt |
| `SPKCOIN[1]` | `SPK_LONG` | Long live Gorf | Coin/start alternate |
| `_SPKGENERIC[0]` | `SPK_TOOBAD` + `SPK_SPACE` + `RANK` + `SPK_CONQUER` | Too bad [rank]. Gorfians conquer another galaxy | Random generic taunt |
| `_SPKGENERIC[1]` | `SPK_TOOBAD` + `SPK_SPACE` + `RANK` + `SPK_TRY` | Too bad [rank]. Try again; I devour your coins | Random generic taunt |
| `_SPKGENERIC[2]` | `SPK_TOOBAD` + `SPK_SPACE` + `RANK` + `SPK_ESCAPE` | Too bad [rank]. You cannot escape the Gorfian robots | Random generic taunt |
| `_SPKGENERIC[3]` | `SPK_TOOBAD` + `SPK_SPACE` + `RANK` + `SPK_GORF` | Too bad [rank]. I am the Gorfian Empire | Random generic taunt |
| `_SPKGENERIC[4]` | `SPK_TOOBAD` + `SPK_SPACE` + `RANK` + `SPK_HAIL` | Too bad [rank]. All hail the supreme Gorfian Empire | Random generic taunt |
| `_SPKGENERIC[5]` | `SPK_BITE` + `SPK_SPACE` + `RANK` + `SPK_CONQUER` | Bite the dust [rank]. Gorfians conquer another galaxy | Random generic taunt |
| `_SPKGENERIC[6]` | `SPK_BITE` + `SPK_SPACE` + `RANK` + `SPK_TRY` | Bite the dust [rank]. Try again; I devour your coins | Random generic taunt |
| `_SPKGENERIC[7]` | `SPK_BITE` + `SPK_SPACE` + `RANK` + `SPK_ESCAPE` | Bite the dust [rank]. You cannot escape the Gorfian robots | Random generic taunt |
| `_SPKGENERIC[8]` | `SPK_BITE` + `SPK_SPACE` + `RANK` + `SPK_GORF` | Bite the dust [rank]. I am the Gorfian Empire | Random generic taunt |
| `_SPKGENERIC[9]` | `SPK_BITE` + `SPK_SPACE` + `RANK` + `SPK_HAIL` | Bite the dust [rank]. All hail the supreme Gorfian Empire | Random generic taunt |
| `_SPKINSULT[0]` | `SPK_HAHA` | Ha ha ha ha | Standalone insult |
| `_SPKINSULT[1]` | `SPK_ENEMY` | Another enemy ship destroyed | Standalone insult |
| `_SPKINSULT[2]` | `SPK_BETCHA` + `SPK_SPACE` + `RANK` | Your end draws near [rank] | Insult followed by rank |
| `_SPKINSULT[3]` | `SPK_BADMOVE` + `SPK_SPACE` + `RANK` | Bad move [rank] | Insult followed by rank |
| `_SPKINSULT[4]` | `SPK_GOTYOU` + `SPK_SPACE` + `RANK` | Got you [rank] | Insult followed by rank |
| `_SPKINSULT[5]` | `SPK_SOME` + `SPK_SPACE` + `RANK` | Some galactic defender you are [rank] | Insult followed by rank |
| `SPEAKSTART[0]` | `SPK_GORF` | I am the Gorfian Empire | Random game-start path |
| `SPEAKSTART[1]` | `SPK_ROBOTS` | Gorfian robots, attack! Attack! | Random game-start path |
| `SPEAKSTART[2]` | `SPK_DOOM` + `SPK_SPACE` + `RANK` | You will meet a Gorfian doom [rank] | Random game-start path |
| `SPEAKSTART[3]` | `SPK_SURVIVAL` + `SPK_SPACE` + `RANK` | Survival is impossible [rank] | Random game-start path |
| `SPEAKSTART[4]` | `SPK_ESCAPE` | You cannot escape the Gorfian robots | Random game-start path |
| `SPEAKSTART[5]` | `SPK_ROBOWARRIOR` + `SPK_SPACE` + `RANK` | Robot warriors, seek and destroy the [rank] | Random game-start path |
| `SPEAKSTART[6]` | `SPK_GORFIAN` | My Gorfian robots are unbeatable | Random game-start path |
| `SPEAKSTART[7]` | `SPK_IAM` | I am a Gorfian consciousness | Random game-start path |
| `SPEAKSTART[8]` | `SPK_PREPARE` + `SPK_SPACE` + `RANK` | Prepare yourself for annihilation [rank] | Random game-start path |
| `SPEAKSTART[9]` | `SPK_PRIS` | Gorfians take no prisoners | Random game-start path |
| `Promotion pattern` | `SPK_PROMOTE` + `SPK_SPACE` + `RANK` | You have been promoted to [rank] | Compound rank announcement |
| `Flagship sequence` | `UNNAMED_A985` + `UNNAMED_A9A8` + `UNNAMED_A9C1` | Next time will be harder, but for now; in the Gorfian chronicles; for hitting my flagship | Three contiguous upper-ROM records |

## Translation requirements

- An X11 translator must recognize all 36 resident keys, including the three upper-ROM records at `$A985`, `$A9A8`, and `$A9C1`.
- The translated table must remain sorted by resident key because the X11 lookup terminates as soon as the requested key is less than the current table entry.
- Compound rank lines must preserve the source order even when the translated `SPK_SPACE` entry is suppressed.
- Encoded bytes must retain bits 6-7. Masking records to six bits is valid only for direct SC-01 analysis, not for rebuilding the game ROM.
