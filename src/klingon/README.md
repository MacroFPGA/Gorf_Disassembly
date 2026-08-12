# Gorf Program 2 Klingon X11 prototype

This directory contains an experimental Klingon X11 language ROM for Gorf Program 2. It follows the working Program-2 German structure and supplies Klingon display text with direct SC-01 pronunciation approximations. It is a prototype for technical and gameplay testing, not a linguistically certified translation.


## Provenance and compatibility

This Klingon X11 is a project-created Program-2 derivative, not a historical Bally/Midway language ROM. Its executable contract comes from the Program-2 German conversion. The underlying 36-entry predecessor-search design is now independently confirmed by both  Program-1 German and French X11 ROMs.

Klingon therefore preserves the historical lookup behavior and the Program-2 `$C000` / `$CC00` interface, while its display text, local SC-01 records, and translation targets are project-specific. The `$CFF2 = $00` byte is inherited from the German template; the shared `GORF` / `DNA` identification record begins separately at `$CFF3`.

## X11 interface

| Address | Entry | Purpose |
| ---: | --- | --- |
| `$C000` | `X11Entry` | Maps the Program-2 speech address in `DE` to a Klingon record and queues it. |
| `$C003` | `KlingonMessageTable` | Begins the 52 length-prefixed Program-2 display records. |
| `$CC00` | `ForeignCoinInputEntry` | Returns foreign-mode coin and start processing to the resident Program-2 routine at `$1769`. |

The `$CC00` hook is mandatory when the Language DIP selects Foreign.

## Display records

Canonical Klingon is case-sensitive and uses apostrophes. The source comments preserve that form. The arcade payload uses uppercase, apostrophe-free text so it remains compatible with Gorf's display repertoire. Indexes 42-47 are blanks or binary control data and remain unchanged.

| ID | English display record | Klingon equivalent | X11 address | Bytes | Notes |
| ---: | --- | --- | ---: | ---: | --- |
| 0 | `MISSION[` | Qu' | `$C003` | 3 |  |
| 1 | `GAME OVER` | rIn Quj | `$C007` | 7 |  |
| 2 | `PLAYER` | QujwI' | `$C00F` | 5 |  |
| 3 | `2` | 2 | `$C015` | 1 |  |
| 4 | `1` | 1 | `$C017` | 1 |  |
| 5 | `GAME` | rIn | `$C019` | 3 |  |
| 6 | `OVER` | Quj | `$C01D` | 3 |  |
| 7 | `GET` | SuvmeH | `$C021` | 6 |  |
| 8 | `READY` | yIghuH | `$C028` | 6 |  |
| 9 | `INSERT ADDITIONAL COIN` | latlh Huch yIlan | `$C02F` | 16 |  |
| 10 | `SELECT 1 PLAYER GAME` | wa' QujwI' Quj yIwIv | `$C040` | 18 |  |
| 11 | `OR` | ghap | `$C053` | 4 |  |
| 12 | `SELECT 1 OR 2 PLAYER GAME` | wa' QujwI' cha' QujwI' ghap yIwIv | `$C058` | 23 |  |
| 13 | `FOR 2 PLAYER GAME` | cha' QujwI' QujmeH | `$C070` | 16 |  |
| 14 | `OR FOR EXTRA SHIPS` | qoj latlh Dujmey | `$C081` | 16 |  |
| 15 | `WITH EXTRA SHIPS` | latlh Dujmey ghaj | `$C092` | 17 |  |
| 16 | `THE EVIL` | nuHIvpu' | `$C0A4` | 7 |  |
| 17 | `GORFIAN ROBOT` | Gorf wo' | `$C0AC` | 7 |  |
| 18 | `EMPIRE HAS ATTACKED` | qoqmey mIgh | `$C0B4` | 11 |  |
| 19 | `YOUR ASSIGNMENT IS TO` | Qu'lIj 'oH | `$C0C0` | 8 |  |
| 20 | `REPEL THE INVASION AND` | yot yIbot 'ej | `$C0C9` | 12 |  |
| 21 | `LAUNCH A COUNTERATTACK` | yIHIvqa' | `$C0D6` | 7 |  |
| 22 | `YOU WILL` | tugh | `$C0DE` | 4 |  |
| 23 | `ENGAGE VARIOUS` | jagh | `$C0E3` | 4 |  |
| 24 | `HOSTILE SPACECRAFT` | Dujmey DaSuv | `$C0E8` | 12 |  |
| 25 | `AS YOU JOURNEY TOWARD` | bIghoStaHDI' | `$C0F5` | 11 |  |
| 26 | `A DRAMATIC CONFRONTATION` | may' Qatlh DaSuv | `$C101` | 15 |  |
| 27 | `WITH THE ENEMY FLAG SHIP` | jagh ra'wI' Duj DaSuv | `$C111` | 19 |  |
| 28 | `THE HIGH` | mIvwa'mey nIv | `$C125` | 12 |  |
| 29 | `SCORES ARE[` | bIH: | `$C132` | 4 |  |
| 30 | `2 SHIPS` | cha' Dujmey | `$C137` | 10 |  |
| 31 | `3 SHIPS` | wej Dujmey | `$C142` | 10 |  |
| 32 | `4 SHIPS` | loS Dujmey | `$C14D` | 10 |  |
| 33 | `6 SHIPS` | jav Dujmey | `$C158` | 10 |  |
| 34 | `ASTRO BATTLES` | Hov may'mey | `$C163` | 10 |  |
| 35 | `GALAXIANS` | qIbnganpu' | `$C16E` | 9 |  |
| 36 | `LASER ATTACK` | nISwI' HIv | `$C178` | 9 |  |
| 37 | `SPACE WARP` | pIvghor | `$C182` | 7 |  |
| 38 | `FLAG SHIP` | ra'wI' Duj | `$C18A` | 8 |  |
| 39 | `1 PLAYER` | wa' QujwI' | `$C193` | 8 |  |
| 40 | `2 PLAYERS` | cha' QujwI' | `$C19C` | 9 |  |
| 41 | `INSERT COIN` | Huch yIlan | `$C1A6` | 10 |  |
| 42 | one space | one space | `$C1B1` | 1 | Structural record; preserved in place |
| 43 | one space | one space | `$C1B3` | 1 | Structural record; preserved in place |
| 44 | `$09` | unchanged control record | `$C1B5` | 1 | Structural record; preserved in place |
| 45 | `$0A,$0B,$09,$0D,$0E` | unchanged control record | `$C1B7` | 5 | Structural record; preserved in place |
| 46 | `$0C,$0B,$09,$0D,$0F` | unchanged control record | `$C1BD` | 5 | Structural record; preserved in place |
| 47 | `$0C` | unchanged control record | `$C1C3` | 1 | Structural record; preserved in place |
| 48 | `SAME PLAYER UP` | QujwI' rap | `$C1C5` | 9 |  |
| 49 | `CREDIT SHIPS[` | Huch Dujmey: | `$C1CF` | 12 |  |
| 50 | `$5C,"1981 MIDWAY MFG CO"` | unchanged copyright record | `$C1DC` | 19 | Copyright record |
| 51 | `ALL RIGHTS RESERVED` | Hoch DIbmey pollu' | `$C1F0` | 17 |  |

## Speech translation

The translator searches 36 sorted Program-2 keys. It provides 34 local Klingon records, suppresses `SPK_SPACE` because the translated rank boundary is handled in the target records, and reuses the resident laugh. Pronunciations are direct SC-01 approximations and require listening review in the emulator.

| ID | Source label | Resident key | English fragment | Klingon equivalent | Notes |
| ---: | --- | ---: | --- | --- | --- |
| 0 | `SPK_INSERT` | `$115D` | Insert coin | Huch yIlan. |  |
| 1 | `SPK_GORF` | `$116D` | I am the Gorfian Empire | Gorf wo' jIH. |  |
| 2 | `SPK_SPACE` | `$1185` | Space | Suppressed; translated ranks provide the boundary. | Suppressed; translated ranks include the required boundary |
| 3 | `SPK_CONQUER` | `$118C` | Gorfians conquer another galaxy | latlh qIb luchargh Gorfnganpu'. |  |
| 4 | `SPK_TRY` | `$11A8` | Try again; I devour your coins | yInIDqa'; HuchlIj vISop. |  |
| 5 | `SPK_LONG` | `$11C7` | Long live Gorf | taHjaj Gorf. |  |
| 6 | `SPK_ROBOTS` | `$11D7` | Gorfian robots, attack! Attack! | Gorf, peHIv! peHIv! |  |
| 7 | `SPK_BADMOVE` | `$11F6` | Bad move | vIHHa'. |  |
| 8 | `SPK_HAHA` | `$1200` | Ha ha ha ha | Language-neutral resident laugh. | Uses the resident language-neutral laugh |
| 9 | `SPK_ESCAPE` | `$120A` | You cannot escape the Gorfian robots | Gorf qoqmeyvo' bInarghlaHbe'. |  |
| 10 | `SPK_GOTYOU` | `$122E` | Got you | qajon. |  |
| 11 | `SPK_NICE` | `$1237` | Nice shot | bach QaQ. |  |
| 12 | `SPK_TOOBAD` | `$1243` | Too bad | Do'Ha'. |  |
| 13 | `SPK_PRIS` | `$124B` | Gorfians take no prisoners | qama'pu' jonbe' Gorfnganpu'. |  |
| 14 | `SPK_CADET` | `$1264` | Cadet | ghojwI'. |  |
| 15 | `SPK_CAPT` | `$126B` | Captain | HoD. |  |
| 16 | `SPK_COLONEL` | `$1274` | Colonel | la'. |  |
| 17 | `SPK_GENERAL` | `$127B` | General | Sa'. |  |
| 18 | `SPK_WARRIOR` | `$1284` | Warrior | SuvwI'. |  |
| 19 | `SPK_AVENGER` | `$128D` | Avenger | bortaSwI'. |  |
| 20 | `SPK_PROMOTE` | `$1298` | You have been promoted to | patlh chu' Dachav: |  |
| 21 | `SPK_SOME` | `$12B2` | Some galactic defender you are | qIb HubwI' qab SoH. |  |
| 22 | `SPK_BITE` | `$12CE` | Bite the dust | lam yIchop. |  |
| 23 | `SPK_HAIL` | `$12DB` | All hail the supreme Gorfian Empire | Gorf wo' quv yIvan. |  |
| 24 | `SPK_ENEMY` | `$12FC` | Another enemy ship destroyed | latlh jagh Duj Qaw'lu'. |  |
| 25 | `SPK_BETCHA` | `$1317` | Your end draws near | tugh bIHegh. |  |
| 26 | `UNNAMED_A985` | `$A985` | Next time will be harder, but for now | Qatlhqu' poH veb, 'ach DaH: |  |
| 27 | `UNNAMED_A9A8` | `$A9A8` | In the Gorfian chronicles | Gorf QonoSDaq. |  |
| 28 | `UNNAMED_A9C1` | `$A9C1` | For hitting my flagship | ra'wI' DujwIj DaqIpta'. |  |
| 29 | `SPK_PUSH` | `$B3BE` | Push a player button | QujwI' DuQwI' yIyuv. |  |
| 30 | `SPK_DOOM` | `$B3D4` | You will meet a Gorfian doom | Gorf Hegh Daghom, |  |
| 31 | `SPK_SURVIVAL` | `$B3EF` | Survival is impossible | bIyInlaHbe', |  |
| 32 | `SPK_ROBOWARRIOR` | `$B405` | Robot warriors, seek and destroy the | qoq SuvwI'pu' DuSam 'ej DuQaw', |  |
| 33 | `SPK_GORFIAN` | `$B426` | My Gorfian robots are unbeatable | SuvwI'pu'wIj DaHoHlaHbe'. |  |
| 34 | `SPK_IAM` | `$B449` | I am a Gorfian consciousness | Gorf yab jIH. |  |
| 35 | `SPK_PREPARE` | `$B465` | Prepare yourself for annihilation | DaQaw'lu'meH yIghuH, |  |

## Phrase selection

Program 2 composes speech from the fragments above; it does not use a separate numeric phrase table. The selector names and path indexes below match the English map in [`docs/SPEECH_MAP.md`](../../docs/SPEECH_MAP.md).

| Selector or path | Resident composition | English result | Klingon result | Notes |
| --- | --- | --- | --- | --- |
| `phrases[0]` | `SPK_INSERT` | Insert coin | Huch yIlan. | Attract table |
| `phrases[1]` | `SPK_GORF` | I am the Gorfian Empire | Gorf wo' jIH. | Attract table |
| `phrases[2]` | `SPK_LONG` | Long live Gorf | taHjaj Gorf. | Attract table |
| `phrases[3]` | `SPK_INSERT` | Insert coin | Huch yIlan. | Intentional duplicate |
| `SPKCOIN[0]` | `SPK_PUSH` | Push a player button | QujwI' DuQwI' yIyuv. | Coin/start prompt |
| `SPKCOIN[1]` | `SPK_LONG` | Long live Gorf | taHjaj Gorf. | Coin/start alternate |
| `_SPKGENERIC[0]` | `SPK_TOOBAD` + `SPK_SPACE` + `RANK` + `SPK_CONQUER` | Too bad [rank]. Gorfians conquer another galaxy | Do'Ha'. [Klingon rank] latlh qIb luchargh Gorfnganpu'. | Random generic taunt |
| `_SPKGENERIC[1]` | `SPK_TOOBAD` + `SPK_SPACE` + `RANK` + `SPK_TRY` | Too bad [rank]. Try again; I devour your coins | Do'Ha'. [Klingon rank] yInIDqa'; HuchlIj vISop. | Random generic taunt |
| `_SPKGENERIC[2]` | `SPK_TOOBAD` + `SPK_SPACE` + `RANK` + `SPK_ESCAPE` | Too bad [rank]. You cannot escape the Gorfian robots | Do'Ha'. [Klingon rank] Gorf qoqmeyvo' bInarghlaHbe'. | Random generic taunt |
| `_SPKGENERIC[3]` | `SPK_TOOBAD` + `SPK_SPACE` + `RANK` + `SPK_GORF` | Too bad [rank]. I am the Gorfian Empire | Do'Ha'. [Klingon rank] Gorf wo' jIH. | Random generic taunt |
| `_SPKGENERIC[4]` | `SPK_TOOBAD` + `SPK_SPACE` + `RANK` + `SPK_HAIL` | Too bad [rank]. All hail the supreme Gorfian Empire | Do'Ha'. [Klingon rank] Gorf wo' quv yIvan. | Random generic taunt |
| `_SPKGENERIC[5]` | `SPK_BITE` + `SPK_SPACE` + `RANK` + `SPK_CONQUER` | Bite the dust [rank]. Gorfians conquer another galaxy | lam yIchop. [Klingon rank] latlh qIb luchargh Gorfnganpu'. | Random generic taunt |
| `_SPKGENERIC[6]` | `SPK_BITE` + `SPK_SPACE` + `RANK` + `SPK_TRY` | Bite the dust [rank]. Try again; I devour your coins | lam yIchop. [Klingon rank] yInIDqa'; HuchlIj vISop. | Random generic taunt |
| `_SPKGENERIC[7]` | `SPK_BITE` + `SPK_SPACE` + `RANK` + `SPK_ESCAPE` | Bite the dust [rank]. You cannot escape the Gorfian robots | lam yIchop. [Klingon rank] Gorf qoqmeyvo' bInarghlaHbe'. | Random generic taunt |
| `_SPKGENERIC[8]` | `SPK_BITE` + `SPK_SPACE` + `RANK` + `SPK_GORF` | Bite the dust [rank]. I am the Gorfian Empire | lam yIchop. [Klingon rank] Gorf wo' jIH. | Random generic taunt |
| `_SPKGENERIC[9]` | `SPK_BITE` + `SPK_SPACE` + `RANK` + `SPK_HAIL` | Bite the dust [rank]. All hail the supreme Gorfian Empire | lam yIchop. [Klingon rank] Gorf wo' quv yIvan. | Random generic taunt |
| `_SPKINSULT[0]` | `SPK_HAHA` | Ha ha ha ha | Language-neutral resident laugh. | Standalone insult |
| `_SPKINSULT[1]` | `SPK_ENEMY` | Another enemy ship destroyed | latlh jagh Duj Qaw'lu'. | Standalone insult |
| `_SPKINSULT[2]` | `SPK_BETCHA` + `SPK_SPACE` + `RANK` | Your end draws near [rank] | tugh bIHegh. [Klingon rank] | Insult followed by rank |
| `_SPKINSULT[3]` | `SPK_BADMOVE` + `SPK_SPACE` + `RANK` | Bad move [rank] | vIHHa'. [Klingon rank] | Insult followed by rank |
| `_SPKINSULT[4]` | `SPK_GOTYOU` + `SPK_SPACE` + `RANK` | Got you [rank] | qajon. [Klingon rank] | Insult followed by rank |
| `_SPKINSULT[5]` | `SPK_SOME` + `SPK_SPACE` + `RANK` | Some galactic defender you are [rank] | qIb HubwI' qab SoH. [Klingon rank] | Insult followed by rank |
| `SPEAKSTART[0]` | `SPK_GORF` | I am the Gorfian Empire | Gorf wo' jIH. | Random game-start path |
| `SPEAKSTART[1]` | `SPK_ROBOTS` | Gorfian robots, attack! Attack! | Gorf, peHIv! peHIv! | Random game-start path |
| `SPEAKSTART[2]` | `SPK_DOOM` + `SPK_SPACE` + `RANK` | You will meet a Gorfian doom [rank] | Gorf Hegh Daghom, [Klingon rank] | Random game-start path |
| `SPEAKSTART[3]` | `SPK_SURVIVAL` + `SPK_SPACE` + `RANK` | Survival is impossible [rank] | bIyInlaHbe', [Klingon rank] | Random game-start path |
| `SPEAKSTART[4]` | `SPK_ESCAPE` | You cannot escape the Gorfian robots | Gorf qoqmeyvo' bInarghlaHbe'. | Random game-start path |
| `SPEAKSTART[5]` | `SPK_ROBOWARRIOR` + `SPK_SPACE` + `RANK` | Robot warriors, seek and destroy the [rank] | qoq SuvwI'pu' DuSam 'ej DuQaw', [Klingon rank] | Random game-start path |
| `SPEAKSTART[6]` | `SPK_GORFIAN` | My Gorfian robots are unbeatable | SuvwI'pu'wIj DaHoHlaHbe'. | Random game-start path |
| `SPEAKSTART[7]` | `SPK_IAM` | I am a Gorfian consciousness | Gorf yab jIH. | Random game-start path |
| `SPEAKSTART[8]` | `SPK_PREPARE` + `SPK_SPACE` + `RANK` | Prepare yourself for annihilation [rank] | DaQaw'lu'meH yIghuH, [Klingon rank] | Random game-start path |
| `SPEAKSTART[9]` | `SPK_PRIS` | Gorfians take no prisoners | qama'pu' jonbe' Gorfnganpu'. | Random game-start path |
| `Promotion pattern` | `SPK_PROMOTE` + `SPK_SPACE` + `RANK` | You have been promoted to [rank] | patlh chu' Dachav: [Klingon rank] | Compound rank announcement |
| `Flagship sequence` | `UNNAMED_A985` + `UNNAMED_A9A8` + `UNNAMED_A9C1` | Next time will be harder, but for now; in the Gorfian chronicles; for hitting my flagship | Qatlhqu' poH veb, 'ach DaH: Gorf QonoSDaq. ra'wI' DujwIj DaqIpta'. | Three contiguous upper-ROM records |

## Queue protection

Program 2's eight-entry ring buffer does not prevent the writer from overtaking the reader. `WaitForSpeechQueueSlot` reserves one empty entry before it calls the resident queue routine. Interrupts remain enabled while it waits, allowing the SC-01 consumer to advance during longer compound announcements.

## Build

Linux:

```sh
./build.sh -k
```

Windows:

```bat
build.bat -k
```

Both scripts assemble the eight Program-2 CPU ROMs as `873a.x1` through `873h.x8`, assemble `src/klingon/KLINGON_X11.asm` as `roms/klingon.x11`, and create `roms/gorfpgm1g.zip`. Inside that compatibility archive, the Klingon bytes use the member name `german.x11`, which is the name expected by the stock MAME driver. `sc01.bin` is required and included so the generated archive is self-contained for speech.

## MAME compatibility

Stock MAME defines neither `gorfpgm2k` nor `gorfpgm1k`. The implemented compatibility target is `gorfpgm1g`; using a Klingon-named set would require a custom MAME driver.

```text
mame -window -skip_gameinfo -rompath roms gorfpgm1g
```

Select `Foreign` for the cabinet Language option. Audit warnings are expected because the compatibility driver describes a Program-1 German set while this archive contains rebuilt Program-2 CPU ROMs and a Klingon X11 image.

## Verification status

Static verification should cover the complete 4096-byte image, 52 display records, 36 sorted speech keys, record lengths, the `$CC00 -> $1769` return path, queue protection, the inherited German-template `$CFF2` byte, and the separate `$CFF3-$CFFF` identification record.

Runtime review should cover attract mode, display text, coin-up, player selection, game start, every rank, all random speech paths, and clean exit. Klingon wording and SC-01 pronunciation remain subject to listening review; the historical German/French comparison validates the lookup architecture, not the Klingon language content.
