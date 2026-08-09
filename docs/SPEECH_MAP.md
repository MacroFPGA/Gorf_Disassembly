<!-- SPEECH_MAP.md -->
# Gorf Program-2 German Language Map

Gorf Program 2 uses two independent foreign-language resources in the X11 ROM:

- a 52-record display-message table beginning at `$C003`;
- a 36-entry speech-address translation table that maps resident Program-2 primitives to German SC-01 records.

The display strings below are exact ROM payloads. German speech text is a normalized transcription of the encoded SC-01 sequences; capitalization and punctuation are editorial. The encoded bytes in `GERMAN_X11.asm` remain the authoritative source.

## Display message map

Each display record consists of one length byte followed by the listed payload. `Bytes` counts the payload only.

| Index | Program-2 English payload | German X11 payload | X11 address | Bytes |
| ---: | --- | --- | ---: | ---: |
| 0 | `MISSION[` | `MISSION[` | `$C003` | 8 |
| 1 | `GAME OVER` | `SPIEL BEENDET` | `$C00C` | 13 |
| 2 | `PLAYER` | `SPIELER` | `$C01A` | 7 |
| 3 | `2` | `2` | `$C022` | 1 |
| 4 | `1` | `1` | `$C024` | 1 |
| 5 | `GAME` | `SPIEL` | `$C026` | 5 |
| 6 | `OVER` | `BEENDET` | `$C02C` | 7 |
| 7 | `GET` | `AUF DIE` | `$C034` | 7 |
| 8 | `READY` | `PLAETZE` | `$C03C` | 7 |
| 9 | `INSERT ADDITIONAL COIN` | `ZUSAETZLICHE MUENZEN EIN` | `$C044` | 24 |
| 10 | `SELECT 1 PLAYER GAME` | `WAEHLEN SIE EINEN SPIELER` | `$C05D` | 25 |
| 11 | `OR` | `ODER` | `$C077` | 4 |
| 12 | `SELECT 1 OR 2 PLAYER GAME` | `EIN ODER ZWEI SPIELER` | `$C07C` | 21 |
| 13 | `FOR 2 PLAYER GAME` | `FUER ZWEI SPIELER` | `$C092` | 17 |
| 14 | `OR FOR EXTRA SHIPS` | `ODER FUER EXTRA SCHIFFE` | `$C0A4` | 23 |
| 15 | `WITH EXTRA SHIPS` | `MIT EXTRA SCHIFFEN` | `$C0BC` | 18 |
| 16 | `THE EVIL` | `DAS BOESE` | `$C0CF` | 9 |
| 17 | `GORFIAN ROBOT` | `GORF-ROBOTERIMPERIUM` | `$C0D9` | 20 |
| 18 | `EMPIRE HAS ATTACKED` | `HAT ANGEGRIFFEN` | `$C0EE` | 15 |
| 19 | `YOUR ASSIGNMENT IS TO` | `IHRE AUFGABE IST` | `$C0FE` | 16 |
| 20 | `REPEL THE INVASION AND` | `DIE INVASION ABZUWEHREN` | `$C10F` | 23 |
| 21 | `LAUNCH A COUNTERATTACK` | `UND GEGENANZUGREIFEN` | `$C127` | 20 |
| 22 | `YOU WILL` | `SIE WERDEN` | `$C13C` | 10 |
| 23 | `ENGAGE VARIOUS` | `VERSCHIEDENE FEINDLICHE` | `$C147` | 23 |
| 24 | `HOSTILE SPACECRAFT` | `RAUMSCHIFFE BEKAEMPFEN` | `$C15F` | 22 |
| 25 | `AS YOU JOURNEY TOWARD` | `AUF IHREM WEG ZUM` | `$C176` | 17 |
| 26 | `A DRAMATIC CONFRONTATION` | `DRAMATISCHEN KAMPF MIT` | `$C188` | 22 |
| 27 | `WITH THE ENEMY FLAG SHIP` | `DEM FEINDLICHEN FLAGSCHIFF` | `$C19F` | 26 |
| 28 | `THE HIGH` | `DIE HOECHSTERGEBNISSE` | `$C1BA` | 21 |
| 29 | `SCORES ARE[` | `SIND[` | `$C1D0` | 5 |
| 30 | `2 SHIPS` | `ZWEI SCHIFFE` | `$C1D6` | 12 |
| 31 | `3 SHIPS` | `DREI SCHIFFE` | `$C1E3` | 12 |
| 32 | `4 SHIPS` | `VIER SCHIFFE` | `$C1F0` | 12 |
| 33 | `6 SHIPS` | `SECHS SCHIFFE` | `$C1FD` | 13 |
| 34 | `ASTRO BATTLES` | `ASTRO BATTLES` | `$C20B` | 13 |
| 35 | `GALAXIANS` | `GALAXIANS` | `$C219` | 9 |
| 36 | `LASER ATTACK` | `LASER ATTACK` | `$C223` | 12 |
| 37 | `SPACE WARP` | `SPACE WARP` | `$C230` | 10 |
| 38 | `FLAG SHIP` | `FLAG SHIP` | `$C23B` | 9 |
| 39 | `1 PLAYER` | `EIN SPIELER` | `$C245` | 11 |
| 40 | `2 PLAYERS` | `ZWEI SPIELER` | `$C251` | 12 |
| 41 | `INSERT COIN` | `GELD EINWERFEN` | `$C25E` | 14 |
| 42 | one space | one space | `$C26D` | 1 |
| 43 | one space | one space | `$C26F` | 1 |
| 44 | `$09` | `$09` | `$C271` | 1 |
| 45 | `$0A,$0B,$09,$0D,$0E` | `$0A,$0B,$09,$0D,$0E` | `$C273` | 5 |
| 46 | `$0C,$0B,$09,$0D,$0F` | `$0C,$0B,$09,$0D,$0F` | `$C279` | 5 |
| 47 | `$0C` | `$0C` | `$C27F` | 1 |
| 48 | `SAME PLAYER UP` | `GLEICHER SPIELER` | `$C281` | 16 |
| 49 | `CREDIT SHIPS[` | `KREDIT SCHIFFE[` | `$C292` | 15 |
| 50 | `$5C,"1981 MIDWAY MFG CO"` | `$5C,"1981 MIDWAY MFG CO"` | `$C2A2` | 19 |
| 51 | `ALL RIGHTS RESERVED` | `ALLE RECHTE VORBEHALTEN` | `$C2B6` | 23 |

Indexes 42 through 47 are structural data used by the Program-2 display system. They are not translated text and must remain byte-for-byte compatible with the resident table.

The source uses ASCII-compatible spellings such as `PLAETZE`, `FUER`, `BOESE`, `HOECHSTERGEBNISSE`, and `ZUSAETZLICHE` because the game does not provide the required umlaut glyphs in these messages.

## Speech primitive map

The Program-2 address in the second column is the key received at `$C000`. The payload counts exclude each record's leading length byte.

| # | Program-2 English primitive | German result | German record |
| ---: | --- | --- | --- |
| 0 | Insert coin<br>`$115D` · 15 bytes | Geld einwerfen | `GermanSpeech_InsertCoin`<br>`$C55E` · 17 bytes |
| 1 | I am the Gorfian Empire<br>`$116D` · 23 bytes | Ich bin der gorfische Herrscher | `GermanSpeech_Gorf`<br>`$C2CE` · 30 bytes |
| 2 | Space<br>`$1185` · 6 bytes | Suppressed; German rank records already begin with `Raum` | `$0000` |
| 3 | Gorfians conquer another galaxy<br>`$118C` · 27 bytes | Die Gorfs haben wieder eine neue Galaxis erobert | `GermanSpeech_Conquer`<br>`$C4C6` · 46 bytes |
| 4 | Try again; I devour your coins<br>`$11A8` · 30 bytes | Versuch's noch mal; ich verschlinge Münzen | `GermanSpeech_Try`<br>`$C487` · 42 bytes |
| 5 | Long live Gorf<br>`$11C7` · 15 bytes | Lang lebe Gorf | `GermanSpeech_Long`<br>`$C2ED` · 16 bytes |
| 6 | Gorfian robots, attack! Attack!<br>`$11D7` · 30 bytes | Gorfische Roboter: Angriff! Angriff! | `GermanSpeech_Robots`<br>`$C317` · 30 bytes |
| 7 | Bad move<br>`$11F6` · 9 bytes | Schlechter Zug | `GermanSpeech_BadMove`<br>`$C3F4` · 16 bytes |
| 8 | Ha ha ha ha<br>`$1200` · 9 bytes | Language-neutral resident laugh | `$1200` · 9 bytes |
| 9 | You cannot escape the Gorfian robots<br>`$120A` · 35 bytes | Du kannst meinen gorfischen Robotern nicht entfliehen | `GermanSpeech_Escape`<br>`$C444` · 51 bytes |
| 10 | Got you<br>`$122E` · 8 bytes | Gorf hat dich geschlagen | `GermanSpeech_GotYou`<br>`$C405` · 23 bytes |
| 11 | Nice shot<br>`$1237` · 11 bytes | Volltreffer | `GermanSpeech_Nice`<br>`$C54F` · 14 bytes |
| 12 | Too bad<br>`$1243` · 7 bytes | Pech gehabt | `GermanSpeech_TooBad`<br>`$C478` · 14 bytes |
| 13 | Gorfians take no prisoners<br>`$124B` · 24 bytes | Gorfs machen keine Gefangenen | `GermanSpeech_Prisoner`<br>`$C3D3` · 32 bytes |
| 14 | Cadet<br>`$1264` · 6 bytes | Raumkadett | `GermanSpeech_Cadet`<br>`$C68C` · 14 bytes |
| 15 | Captain<br>`$126B` · 8 bytes | Raumhauptmann | `GermanSpeech_Captain`<br>`$C69B` · 19 bytes |
| 16 | Colonel<br>`$1274` · 6 bytes | Raumoberst | `GermanSpeech_Colonel`<br>`$C6AF` · 15 bytes |
| 17 | General<br>`$127B` · 8 bytes | Raumgeneral | `GermanSpeech_General`<br>`$C6BF` · 16 bytes |
| 18 | Warrior<br>`$1284` · 8 bytes | Raummarschall | `GermanSpeech_Warrior`<br>`$C6D0` · 15 bytes |
| 19 | Avenger<br>`$128D` · 10 bytes | Rächer des Weltraums | `GermanSpeech_Avenger`<br>`$C6E0` · 23 bytes |
| 20 | You have been promoted to<br>`$1298` · 25 bytes | Sie werden ernannt zum | `GermanSpeech_Promote`<br>`$C673` · 24 bytes |
| 21 | Some galactic defender you are<br>`$12B2` · 27 bytes | Du bist eine galaktische Niete | `GermanSpeech_Some`<br>`$C5A5` · 33 bytes |
| 22 | Bite the dust<br>`$12CE` · 12 bytes | Beiß ins Gras | `GermanSpeech_Bite`<br>`$C4B2` · 19 bytes |
| 23 | All hail the supreme Gorfian Empire<br>`$12DB` · 32 bytes | Wir rufen das gorfische Reich aus | `GermanSpeech_Hail`<br>`$C4F5` · 39 bytes |
| 24 | Another enemy ship destroyed<br>`$12FC` · 26 bytes | Wieder ein feindliches Schiff zerstört | `GermanSpeech_Enemy`<br>`$C41D` · 38 bytes |
| 25 | Your end draws near<br>`$1317` · 14 bytes | Dein letztes Stündlein schlägt | `GermanSpeech_Betcha`<br>`$C5C7` · 34 bytes |
| 26 | Next time will be harder, but for now<br>`$A985` · 34 bytes | Nächstes Mal wirst du dir die Zähne ausbeißen | `GermanSpeech_For_A985`<br>`$C51D` · 49 bytes |
| 27 | In the Gorfian chronicles<br>`$A9A8` · 24 bytes | Aber jetzt gehst du in die Geschichte der Gorfs ein | `GermanSpeech_For_A9A8`<br>`$C5EA` · 55 bytes |
| 28 | For hitting my flagship<br>`$A9C1` · 21 bytes | Für das Abschießen meines Flaggschiffes | `GermanSpeech_For_A9C1`<br>`$C64B` · 39 bytes |
| 29 | Push a player button<br>`$B3BE` · 21 bytes | Spielerknopf betätigen | `GermanSpeech_Push`<br>`$C2FE` · 24 bytes |
| 30 | You will meet a Gorfian doom<br>`$B3D4` · 26 bytes | Du wirst ein gorfisches Schicksal erleiden | `GermanSpeech_Doom`<br>`$C336` · 45 bytes |
| 31 | Survival is impossible<br>`$B3EF` · 21 bytes | Überleben ist unmöglich | `GermanSpeech_Survival`<br>`$C364` · 31 bytes |
| 32 | Robot warriors, seek and destroy the<br>`$B405` · 32 bytes | Roboterangreifer verfolgt und vernichtet den | `GermanSpeech_RoboWarrior`<br>`$C570` · 52 bytes |
| 33 | My Gorfian robots are unbeatable<br>`$B426` · 34 bytes | Meine gorfischen Roboter sind unbesiegbar | `GermanSpeech_Gorfian`<br>`$C384` · 42 bytes |
| 34 | I am a Gorfian consciousness<br>`$B449` · 27 bytes | Ich bin das gorfische Bewusstsein | `GermanSpeech_IAm`<br>`$C3AF` · 35 bytes |
| 35 | Prepare yourself for annihilation<br>`$B465` · 30 bytes | Bereite dich auf deine Vernichtung vor | `GermanSpeech_Prepare`<br>`$C622` · 40 bytes |

## Compound rank speech

Program 2 constructs several complete announcements from multiple queued primitives. The English form inserts the resident `SPACE` primitive before the rank. The German mapping suppresses that primitive because the translated rank itself begins with `Raum`.

| Context | Program-2 composition | German composition |
| --- | --- | --- |
| Promotion | You have been promoted to + Space + rank | Sie werden ernannt zum + Raumrank |
| Doom taunt | You will meet a Gorfian doom + Space + rank | Du wirst ein gorfisches Schicksal erleiden + Raumrank |
| Survival taunt | Survival is impossible + Space + rank | Überleben ist unmöglich + Raumrank |
| Robot-warrior taunt | Robot warriors, seek and destroy the + Space + rank | Roboterangreifer verfolgt und vernichtet den + Raumrank |
| Prepare taunt | Prepare yourself for annihilation + Space + rank | Bereite dich auf deine Vernichtung vor + Raumrank |

The complete German phrases are substantially longer than their English counterparts. Program 2 can enqueue these fragments faster than the SC-01 consumer finishes them, which is why the X11 translator checks for an available ring-buffer entry before calling the resident queue routine.

## ROM encoding

Each speech record begins with a one-byte payload count followed by encoded SC-01 data. Bits 0-5 select the phoneme. Bits 6 and 7 retain the game's inflection state and are significant ROM data.

Direct SC-01 playback data may mask each byte with `$3F`, but the X11 ROM records must preserve the complete encoded byte values shown in `GERMAN_X11.asm`.
