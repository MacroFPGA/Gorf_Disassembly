# Gorf Program 2 German X11 language ROM

This directory contains the German X11 language ROM adapted for Gorf Program 2. The 4 KB image combines the established German display and SC-01 speech data with the resident addresses, message order, queue behavior, and input return path required by Program 2.

Program 1 and Program 2 do not use interchangeable X11 images. Their resident speech addresses, message indexes, queue entry points, and foreign-mode input paths differ.

## X11 interface

| Address | Entry | Purpose |
| ---: | --- | --- |
| `$C000` | `X11Entry` | Maps the Program-2 speech address in `DE` to a German record and queues it. |
| `$C003` | `GermanMessageTable` | Begins the 52 length-prefixed Program-2 display records. |
| `$CC00` | `ForeignCoinInputEntry` | Returns foreign-mode coin and start processing to the resident Program-2 routine at `$1769`. |

The `$CC00` hook is mandatory. With the Language DIP set to Foreign, Program 2 branches there before processing coin and start inputs. A Program-1 image leaves that path unresolved for this build.

## Display records

Each record contains one payload-length byte followed by the payload. The German table retains all 52 Program-2 positions. Indexes 42-47 are blanks or binary control data and are not translated. Printable German uses `AE`, `OE`, and `UE` where the resident character set lacks umlaut glyphs.

| ID | English display record | German equivalent | X11 address | Bytes | Notes |
| ---: | --- | --- | ---: | ---: | --- |
| 0 | `MISSION[` | `MISSION[` | `$C003` | 8 |  |
| 1 | `GAME OVER` | `SPIEL BEENDET` | `$C00C` | 13 |  |
| 2 | `PLAYER` | `SPIELER` | `$C01A` | 7 |  |
| 3 | `2` | `2` | `$C022` | 1 |  |
| 4 | `1` | `1` | `$C024` | 1 |  |
| 5 | `GAME` | `SPIEL` | `$C026` | 5 |  |
| 6 | `OVER` | `BEENDET` | `$C02C` | 7 |  |
| 7 | `GET` | `AUF DIE` | `$C034` | 7 |  |
| 8 | `READY` | `PLAETZE` | `$C03C` | 7 |  |
| 9 | `INSERT ADDITIONAL COIN` | `ZUSAETZLICHE MUENZEN EIN` | `$C044` | 24 |  |
| 10 | `SELECT 1 PLAYER GAME` | `WAEHLEN SIE EINEN SPIELER` | `$C05D` | 25 |  |
| 11 | `OR` | `ODER` | `$C077` | 4 |  |
| 12 | `SELECT 1 OR 2 PLAYER GAME` | `EIN ODER ZWEI SPIELER` | `$C07C` | 21 |  |
| 13 | `FOR 2 PLAYER GAME` | `FUER ZWEI SPIELER` | `$C092` | 17 |  |
| 14 | `OR FOR EXTRA SHIPS` | `ODER FUER EXTRA SCHIFFE` | `$C0A4` | 23 |  |
| 15 | `WITH EXTRA SHIPS` | `MIT EXTRA SCHIFFEN` | `$C0BC` | 18 |  |
| 16 | `THE EVIL` | `DAS BOESE` | `$C0CF` | 9 |  |
| 17 | `GORFIAN ROBOT` | `GORF-ROBOTERIMPERIUM` | `$C0D9` | 20 |  |
| 18 | `EMPIRE HAS ATTACKED` | `HAT ANGEGRIFFEN` | `$C0EE` | 15 |  |
| 19 | `YOUR ASSIGNMENT IS TO` | `IHRE AUFGABE IST` | `$C0FE` | 16 |  |
| 20 | `REPEL THE INVASION AND` | `DIE INVASION ABZUWEHREN` | `$C10F` | 23 |  |
| 21 | `LAUNCH A COUNTERATTACK` | `UND GEGENANZUGREIFEN` | `$C127` | 20 |  |
| 22 | `YOU WILL` | `SIE WERDEN` | `$C13C` | 10 |  |
| 23 | `ENGAGE VARIOUS` | `VERSCHIEDENE FEINDLICHE` | `$C147` | 23 |  |
| 24 | `HOSTILE SPACECRAFT` | `RAUMSCHIFFE BEKAEMPFEN` | `$C15F` | 22 |  |
| 25 | `AS YOU JOURNEY TOWARD` | `AUF IHREM WEG ZUM` | `$C176` | 17 |  |
| 26 | `A DRAMATIC CONFRONTATION` | `DRAMATISCHEN KAMPF MIT` | `$C188` | 22 |  |
| 27 | `WITH THE ENEMY FLAG SHIP` | `DEM FEINDLICHEN FLAGSCHIFF` | `$C19F` | 26 |  |
| 28 | `THE HIGH` | `DIE HOECHSTERGEBNISSE` | `$C1BA` | 21 |  |
| 29 | `SCORES ARE[` | `SIND[` | `$C1D0` | 5 |  |
| 30 | `2 SHIPS` | `ZWEI SCHIFFE` | `$C1D6` | 12 |  |
| 31 | `3 SHIPS` | `DREI SCHIFFE` | `$C1E3` | 12 |  |
| 32 | `4 SHIPS` | `VIER SCHIFFE` | `$C1F0` | 12 |  |
| 33 | `6 SHIPS` | `SECHS SCHIFFE` | `$C1FD` | 13 |  |
| 34 | `ASTRO BATTLES` | `ASTRO BATTLES` | `$C20B` | 13 |  |
| 35 | `GALAXIANS` | `GALAXIANS` | `$C219` | 9 |  |
| 36 | `LASER ATTACK` | `LASER ATTACK` | `$C223` | 12 |  |
| 37 | `SPACE WARP` | `SPACE WARP` | `$C230` | 10 |  |
| 38 | `FLAG SHIP` | `FLAG SHIP` | `$C23B` | 9 |  |
| 39 | `1 PLAYER` | `EIN SPIELER` | `$C245` | 11 |  |
| 40 | `2 PLAYERS` | `ZWEI SPIELER` | `$C251` | 12 |  |
| 41 | `INSERT COIN` | `GELD EINWERFEN` | `$C25E` | 14 |  |
| 42 | one space | one space | `$C26D` | 1 | Structural record; preserved in place |
| 43 | one space | one space | `$C26F` | 1 | Structural record; preserved in place |
| 44 | `$09` | `$09` | `$C271` | 1 | Structural record; preserved in place |
| 45 | `$0A,$0B,$09,$0D,$0E` | `$0A,$0B,$09,$0D,$0E` | `$C273` | 5 | Structural record; preserved in place |
| 46 | `$0C,$0B,$09,$0D,$0F` | `$0C,$0B,$09,$0D,$0F` | `$C279` | 5 | Structural record; preserved in place |
| 47 | `$0C` | `$0C` | `$C27F` | 1 | Structural record; preserved in place |
| 48 | `SAME PLAYER UP` | `GLEICHER SPIELER` | `$C281` | 16 |  |
| 49 | `CREDIT SHIPS[` | `KREDIT SCHIFFE[` | `$C292` | 15 |  |
| 50 | `$5C,"1981 MIDWAY MFG CO"` | `$5C,"1981 MIDWAY MFG CO"` | `$C2A2` | 19 | Copyright record |
| 51 | `ALL RIGHTS RESERVED` | `ALLE RECHTE VORBEHALTEN` | `$C2B6` | 23 |  |

## Speech translation

The translator searches 36 sorted Program-2 keys. It provides 34 German records, suppresses the resident `SPK_SPACE` record because the translated rank names already begin with `Raum`, and reuses the resident laugh.

| ID | Source label | Resident key | English fragment | German equivalent | Notes |
| ---: | --- | ---: | --- | --- | --- |
| 0 | `SPK_INSERT` | `$115D` | Insert coin | Geld einwerfen |  |
| 1 | `SPK_GORF` | `$116D` | I am the Gorfian Empire | Ich bin der gorfische Herrscher |  |
| 2 | `SPK_SPACE` | `$1185` | Space | Suppressed; German rank records already begin with `Raum` | Suppressed; translated ranks include the required boundary |
| 3 | `SPK_CONQUER` | `$118C` | Gorfians conquer another galaxy | Die Gorfs haben wieder eine neue Galaxis erobert |  |
| 4 | `SPK_TRY` | `$11A8` | Try again; I devour your coins | Versuch's noch mal; ich verschlinge Münzen |  |
| 5 | `SPK_LONG` | `$11C7` | Long live Gorf | Lang lebe Gorf |  |
| 6 | `SPK_ROBOTS` | `$11D7` | Gorfian robots, attack! Attack! | Gorfische Roboter: Angriff! Angriff! |  |
| 7 | `SPK_BADMOVE` | `$11F6` | Bad move | Schlechter Zug |  |
| 8 | `SPK_HAHA` | `$1200` | Ha ha ha ha | Language-neutral resident laugh | Uses the resident language-neutral laugh |
| 9 | `SPK_ESCAPE` | `$120A` | You cannot escape the Gorfian robots | Du kannst meinen gorfischen Robotern nicht entfliehen |  |
| 10 | `SPK_GOTYOU` | `$122E` | Got you | Gorf hat dich geschlagen |  |
| 11 | `SPK_NICE` | `$1237` | Nice shot | Volltreffer |  |
| 12 | `SPK_TOOBAD` | `$1243` | Too bad | Pech gehabt |  |
| 13 | `SPK_PRIS` | `$124B` | Gorfians take no prisoners | Gorfs machen keine Gefangenen |  |
| 14 | `SPK_CADET` | `$1264` | Cadet | Raumkadett |  |
| 15 | `SPK_CAPT` | `$126B` | Captain | Raumhauptmann |  |
| 16 | `SPK_COLONEL` | `$1274` | Colonel | Raumoberst |  |
| 17 | `SPK_GENERAL` | `$127B` | General | Raumgeneral |  |
| 18 | `SPK_WARRIOR` | `$1284` | Warrior | Raummarschall |  |
| 19 | `SPK_AVENGER` | `$128D` | Avenger | Rächer des Weltraums |  |
| 20 | `SPK_PROMOTE` | `$1298` | You have been promoted to | Sie werden ernannt zum |  |
| 21 | `SPK_SOME` | `$12B2` | Some galactic defender you are | Du bist eine galaktische Niete |  |
| 22 | `SPK_BITE` | `$12CE` | Bite the dust | Beiß ins Gras |  |
| 23 | `SPK_HAIL` | `$12DB` | All hail the supreme Gorfian Empire | Wir rufen das gorfische Reich aus |  |
| 24 | `SPK_ENEMY` | `$12FC` | Another enemy ship destroyed | Wieder ein feindliches Schiff zerstört |  |
| 25 | `SPK_BETCHA` | `$1317` | Your end draws near | Dein letztes Stündlein schlägt |  |
| 26 | `UNNAMED_A985` | `$A985` | Next time will be harder, but for now | Nächstes Mal wirst du dir die Zähne ausbeißen |  |
| 27 | `UNNAMED_A9A8` | `$A9A8` | In the Gorfian chronicles | Aber jetzt gehst du in die Geschichte der Gorfs ein |  |
| 28 | `UNNAMED_A9C1` | `$A9C1` | For hitting my flagship | Für das Abschießen meines Flaggschiffes |  |
| 29 | `SPK_PUSH` | `$B3BE` | Push a player button | Spielerknopf betätigen |  |
| 30 | `SPK_DOOM` | `$B3D4` | You will meet a Gorfian doom | Du wirst ein gorfisches Schicksal erleiden |  |
| 31 | `SPK_SURVIVAL` | `$B3EF` | Survival is impossible | Überleben ist unmöglich |  |
| 32 | `SPK_ROBOWARRIOR` | `$B405` | Robot warriors, seek and destroy the | Roboterangreifer verfolgt und vernichtet den |  |
| 33 | `SPK_GORFIAN` | `$B426` | My Gorfian robots are unbeatable | Meine gorfischen Roboter sind unbesiegbar |  |
| 34 | `SPK_IAM` | `$B449` | I am a Gorfian consciousness | Ich bin das gorfische Bewusstsein |  |
| 35 | `SPK_PREPARE` | `$B465` | Prepare yourself for annihilation | Bereite dich auf deine Vernichtung vor |  |

## Phrase selection

Program 2 composes speech from the fragments above; it does not use a separate numeric phrase table. The selector names and path indexes below match the English map in [`docs/SPEECH_MAP.md`](../../docs/SPEECH_MAP.md).

| Selector or path | Resident composition | English result | German result | Notes |
| --- | --- | --- | --- | --- |
| `phrases[0]` | `SPK_INSERT` | Insert coin | Geld einwerfen | Attract table |
| `phrases[1]` | `SPK_GORF` | I am the Gorfian Empire | Ich bin der gorfische Herrscher | Attract table |
| `phrases[2]` | `SPK_LONG` | Long live Gorf | Lang lebe Gorf | Attract table |
| `phrases[3]` | `SPK_INSERT` | Insert coin | Geld einwerfen | Intentional duplicate |
| `SPKCOIN[0]` | `SPK_PUSH` | Push a player button | Spielerknopf betätigen | Coin/start prompt |
| `SPKCOIN[1]` | `SPK_LONG` | Long live Gorf | Lang lebe Gorf | Coin/start alternate |
| `_SPKGENERIC[0]` | `SPK_TOOBAD` + `SPK_SPACE` + `RANK` + `SPK_CONQUER` | Too bad [rank]. Gorfians conquer another galaxy | Pech gehabt [German rank] Die Gorfs haben wieder eine neue Galaxis erobert | Random generic taunt |
| `_SPKGENERIC[1]` | `SPK_TOOBAD` + `SPK_SPACE` + `RANK` + `SPK_TRY` | Too bad [rank]. Try again; I devour your coins | Pech gehabt [German rank] Versuch's noch mal; ich verschlinge Münzen | Random generic taunt |
| `_SPKGENERIC[2]` | `SPK_TOOBAD` + `SPK_SPACE` + `RANK` + `SPK_ESCAPE` | Too bad [rank]. You cannot escape the Gorfian robots | Pech gehabt [German rank] Du kannst meinen gorfischen Robotern nicht entfliehen | Random generic taunt |
| `_SPKGENERIC[3]` | `SPK_TOOBAD` + `SPK_SPACE` + `RANK` + `SPK_GORF` | Too bad [rank]. I am the Gorfian Empire | Pech gehabt [German rank] Ich bin der gorfische Herrscher | Random generic taunt |
| `_SPKGENERIC[4]` | `SPK_TOOBAD` + `SPK_SPACE` + `RANK` + `SPK_HAIL` | Too bad [rank]. All hail the supreme Gorfian Empire | Pech gehabt [German rank] Wir rufen das gorfische Reich aus | Random generic taunt |
| `_SPKGENERIC[5]` | `SPK_BITE` + `SPK_SPACE` + `RANK` + `SPK_CONQUER` | Bite the dust [rank]. Gorfians conquer another galaxy | Beiß ins Gras [German rank] Die Gorfs haben wieder eine neue Galaxis erobert | Random generic taunt |
| `_SPKGENERIC[6]` | `SPK_BITE` + `SPK_SPACE` + `RANK` + `SPK_TRY` | Bite the dust [rank]. Try again; I devour your coins | Beiß ins Gras [German rank] Versuch's noch mal; ich verschlinge Münzen | Random generic taunt |
| `_SPKGENERIC[7]` | `SPK_BITE` + `SPK_SPACE` + `RANK` + `SPK_ESCAPE` | Bite the dust [rank]. You cannot escape the Gorfian robots | Beiß ins Gras [German rank] Du kannst meinen gorfischen Robotern nicht entfliehen | Random generic taunt |
| `_SPKGENERIC[8]` | `SPK_BITE` + `SPK_SPACE` + `RANK` + `SPK_GORF` | Bite the dust [rank]. I am the Gorfian Empire | Beiß ins Gras [German rank] Ich bin der gorfische Herrscher | Random generic taunt |
| `_SPKGENERIC[9]` | `SPK_BITE` + `SPK_SPACE` + `RANK` + `SPK_HAIL` | Bite the dust [rank]. All hail the supreme Gorfian Empire | Beiß ins Gras [German rank] Wir rufen das gorfische Reich aus | Random generic taunt |
| `_SPKINSULT[0]` | `SPK_HAHA` | Ha ha ha ha | Language-neutral resident laugh | Standalone insult |
| `_SPKINSULT[1]` | `SPK_ENEMY` | Another enemy ship destroyed | Wieder ein feindliches Schiff zerstört | Standalone insult |
| `_SPKINSULT[2]` | `SPK_BETCHA` + `SPK_SPACE` + `RANK` | Your end draws near [rank] | Dein letztes Stündlein schlägt [German rank] | Insult followed by rank |
| `_SPKINSULT[3]` | `SPK_BADMOVE` + `SPK_SPACE` + `RANK` | Bad move [rank] | Schlechter Zug [German rank] | Insult followed by rank |
| `_SPKINSULT[4]` | `SPK_GOTYOU` + `SPK_SPACE` + `RANK` | Got you [rank] | Gorf hat dich geschlagen [German rank] | Insult followed by rank |
| `_SPKINSULT[5]` | `SPK_SOME` + `SPK_SPACE` + `RANK` | Some galactic defender you are [rank] | Du bist eine galaktische Niete [German rank] | Insult followed by rank |
| `SPEAKSTART[0]` | `SPK_GORF` | I am the Gorfian Empire | Ich bin der gorfische Herrscher | Random game-start path |
| `SPEAKSTART[1]` | `SPK_ROBOTS` | Gorfian robots, attack! Attack! | Gorfische Roboter: Angriff! Angriff! | Random game-start path |
| `SPEAKSTART[2]` | `SPK_DOOM` + `SPK_SPACE` + `RANK` | You will meet a Gorfian doom [rank] | Du wirst ein gorfisches Schicksal erleiden [German rank] | Random game-start path |
| `SPEAKSTART[3]` | `SPK_SURVIVAL` + `SPK_SPACE` + `RANK` | Survival is impossible [rank] | Überleben ist unmöglich [German rank] | Random game-start path |
| `SPEAKSTART[4]` | `SPK_ESCAPE` | You cannot escape the Gorfian robots | Du kannst meinen gorfischen Robotern nicht entfliehen | Random game-start path |
| `SPEAKSTART[5]` | `SPK_ROBOWARRIOR` + `SPK_SPACE` + `RANK` | Robot warriors, seek and destroy the [rank] | Roboterangreifer verfolgt und vernichtet den [German rank] | Random game-start path |
| `SPEAKSTART[6]` | `SPK_GORFIAN` | My Gorfian robots are unbeatable | Meine gorfischen Roboter sind unbesiegbar | Random game-start path |
| `SPEAKSTART[7]` | `SPK_IAM` | I am a Gorfian consciousness | Ich bin das gorfische Bewusstsein | Random game-start path |
| `SPEAKSTART[8]` | `SPK_PREPARE` + `SPK_SPACE` + `RANK` | Prepare yourself for annihilation [rank] | Bereite dich auf deine Vernichtung vor [German rank] | Random game-start path |
| `SPEAKSTART[9]` | `SPK_PRIS` | Gorfians take no prisoners | Gorfs machen keine Gefangenen | Random game-start path |
| `Promotion pattern` | `SPK_PROMOTE` + `SPK_SPACE` + `RANK` | You have been promoted to [rank] | Sie werden ernannt zum [German rank] | Compound rank announcement |
| `Flagship sequence` | `UNNAMED_A985` + `UNNAMED_A9A8` + `UNNAMED_A9C1` | Next time will be harder, but for now; in the Gorfian chronicles; for hitting my flagship | Nächstes Mal wirst du dir die Zähne ausbeißen Aber jetzt gehst du in die Geschichte der Gorfs ein Für das Abschießen meines Flaggschiffes | Three contiguous upper-ROM records |

## Queue protection

Program 2's eight-entry ring buffer does not prevent the writer from overtaking the reader. German records are often longer than their English counterparts, especially in rank announcements. `WaitForSpeechQueueSlot` reserves one empty entry before it calls the resident queue routine. Interrupts remain enabled while it waits, allowing playback to advance.

## Build

Linux:

```sh
./build.sh -g
```

Windows:

```bat
build.bat -g
```

Both scripts assemble the eight Program-2 CPU ROMs as `873a.x1` through `873h.x8`, assemble `src/german/GERMAN_X11.asm` as `roms/german.x11`, and create `roms/gorfpgm1g.zip`. The configured SC-01 speech ROM is included when present. Running the scripts without a language option retains the normal `gorf-a.bin` through `gorf-h.bin` output and creates `gorf.zip`.

## MAME compatibility

Stock MAME has no `gorfpgm2g` set. Its available German driver is `gorfpgm1g`, so the Program-2 build uses that archive and member naming for compatibility:

```text
mame -window -skip_gameinfo -rompath roms gorfpgm1g
```

Select `Foreign` for the cabinet Language option. MAME identifies the driver as a Program-1 German set, so audit warnings are expected for the rebuilt Program-2 CPU ROMs and adapted X11 image.

## Verification and provenance

The German speech and display payloads derive from the existing German X11 work in this repository; the Program-2-specific interface, message order, address map, and queue guard are adaptations. Verification should cover the complete 4096-byte image, 52 display records, 36 sorted speech keys, the `$CC00 -> $1769` return path, attract mode, coin-up, player selection, rank announcements, and game start.
