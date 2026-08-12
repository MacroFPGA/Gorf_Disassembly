# Gorf Program 2 French X11 language ROM

This directory contains the French X11 language ROM adapted for Gorf Program 2. The 4 KB image preserves the  Program-1 French SC-01 speech records while retargeting the display table, resident speech keys, queue entry, and foreign-mode input path required by Program 2.

Program 1 and Program 2 do not use interchangeable X11 images. The  French ROM is an executable/data hybrid, and its Program-1 addresses cannot be used unchanged by Program 2.

## Provenance

The historical French language ROM is `french_gorf.x11`:

- Size: 4096 bytes
- CRC32: `759d7f66`
- SHA-1: `339b719fc1ffe3c2be49fbd5cf562d06134abadc`

The Program-1 French and German sets use byte-identical X1-X8 CPU ROMs, isolating their language differences to X11. The  French X11 has this verified layout:

| Range | Program-1 French content |
| ---: | --- |
| `$C000-$C002` | `JP $C737` translator entry |
| `$C003-$C2FF` | 54 length-prefixed display/control records |
| `$C300-$C6A6` | 34 local French SC-01 records |
| `$C6A7-$C6EE` | 36 translation targets |
| `$C6EF-$C736` | 36 sorted Program-1 English speech keys |
| `$C737-$C76E` | predecessor-search translator, dispatching through Program 1 `$10CA` |
| `$C76F-$CFF2` | erased `$FF` padding |
| `$CFF3-$CFFF` | common `GORF` / `DNA` identification record |

The  French and German X11 ROMs independently implement the same 36-entry predecessor-search algorithm. The Program-2 source preserves that lookup behavior, not the original physical layout.

The MAME-tested Program-2 French image produced by this source lineage is:

- Size: 4096 bytes
- CRC32: `c6f7e746`
- SHA-1: `627346ab5be396f54b55b90e2af59ffbb75b121f`

## X11 interface

| Address | Entry | Purpose |
| ---: | --- | --- |
| `$C000` | `X11Entry` | Maps the Program-2 speech address in `DE` to a French record and queues it. |
| `$C003` | `FrenchMessageTable` | Begins the 52 length-prefixed Program-2 display records. |
| `$CC00` | `ForeignCoinInputEntry` | Returns foreign-mode coin and start processing to the resident Program-2 routine at `$1769`. |

The `$CC00` hook is mandatory. With the Language DIP set to Foreign, Program 2 branches there before processing coin and start inputs.

## Display records

Each record contains one payload-length byte followed by the payload. Program 2 requires exactly 52 positions. The  Program-1 French table contains 54 records and uses different prompt/control boundaries, so the Program-2 table is an adaptation rather than a positional copy.

Indexes 42-47 are Program-2 structural records and remain byte-for-byte identical to the resident table. Records 49-51 are Program-2-only credit/copyright material, which is why the Program-2 French attract sequence includes the Midway copyright screen that the original Program-1 French set does not.

| ID | English display record | French equivalent | X11 address | Bytes | Notes |
| ---: | --- | --- | ---: | ---: | --- |
| 0 | `MISSION[` | `MISSION[` | `$C003` | 8 |  |
| 1 | `GAME OVER` | `FIN DU JEU` | `$C00C` | 10 |  |
| 2 | `PLAYER` | `JOUEUR` | `$C017` | 6 |  |
| 3 | `2` | `2` | `$C01E` | 1 | Program-2 form; Program-1 French used `NO 2` / `NO 1` |
| 4 | `1` | `1` | `$C020` | 1 | Program-2 form; Program-1 French used `NO 2` / `NO 1` |
| 5 | `GAME` | `FIN` | `$C022` | 3 |  |
| 6 | `OVER` | `DU JEU` | `$C026` | 6 |  |
| 7 | `GET` | `TENEZ VOUS` | `$C02D` | 10 |  |
| 8 | `READY` | `PRET` | `$C038` | 4 |  |
| 9 | `INSERT ADDITIONAL COIN` | `DEPOSER JETON SUPPLEMENTAIRE` | `$C03D` | 28 | Recomposed for Program-2 prompt boundaries from Program-1 French wording |
| 10 | `SELECT 1 PLAYER GAME` | `SELECTIONNER 1 JOUEUR` | `$C05A` | 21 | Recomposed for Program-2 prompt boundaries from Program-1 French wording |
| 11 | `OR` | `OU` | `$C070` | 2 | Recomposed for Program-2 prompt boundaries from Program-1 French wording |
| 12 | `SELECT 1 OR 2 PLAYER GAME` | `A 1 OU 2 PARTICIPANTS` | `$C073` | 21 | Recomposed for Program-2 prompt boundaries from Program-1 French wording |
| 13 | `FOR 2 PLAYER GAME` | `POUR UN JEU A 2` | `$C089` | 15 | Recomposed for Program-2 prompt boundaries from Program-1 French wording |
| 14 | `OR FOR EXTRA SHIPS` | `OU POUR VAISSEAUX EN PLUS` | `$C099` | 25 | Recomposed for Program-2 prompt boundaries from Program-1 French wording |
| 15 | `WITH EXTRA SHIPS` | `AVEC VAISSEAUX EN PLUS` | `$C0B3` | 22 | Recomposed for Program-2 prompt boundaries from Program-1 French wording |
| 16 | `THE EVIL` | `L EMPIRE` | `$C0CA` | 8 |  |
| 17 | `GORFIAN ROBOT` | `DES DEMONS ROBOTS GORFIENS` | `$C0D3` | 26 |  |
| 18 | `EMPIRE HAS ATTACKED` | `A ATTAQUE` | `$C0EE` | 9 |  |
| 19 | `YOUR ASSIGNMENT IS TO` | `VOTRE DEVOIR EST DE` | `$C0F8` | 19 |  |
| 20 | `REPEL THE INVASION AND` | `REPOUSSER L INVASION ET DE` | `$C10C` | 26 |  |
| 21 | `LAUNCH A COUNTERATTACK` | `LANCER UNE CONTRE ATTAQUE` | `$C127` | 25 |  |
| 22 | `YOU WILL` | `VOUS DEVREZ` | `$C141` | 11 |  |
| 23 | `ENGAGE VARIOUS` | `VOUS MESURER A DIFFERENTS` | `$C14D` | 25 |  |
| 24 | `HOSTILE SPACECRAFT` | `VAISSEAUX ENNEMIS SUR VOTRE` | `$C167` | 27 |  |
| 25 | `AS YOU JOURNEY TOWARD` | `ROUTE VERS LA SUPREME` | `$C183` | 21 |  |
| 26 | `A DRAMATIC CONFRONTATION` | `CONFRONTATION AVEC` | `$C199` | 18 |  |
| 27 | `WITH THE ENEMY FLAG SHIP` | `LE VAISSEAU AMIRAL ENNEMI` | `$C1AC` | 25 |  |
| 28 | `THE HIGH` | `LES HAUTS RESULTATS` | `$C1C6` | 19 |  |
| 29 | `SCORES ARE[` | `SONT[` | `$C1DA` | 5 |  |
| 30 | `2 SHIPS` | `2 VAISSEAUX` | `$C1E0` | 11 |  |
| 31 | `3 SHIPS` | `3 VAISSEAUX` | `$C1EC` | 11 |  |
| 32 | `4 SHIPS` | `4 VAISSEAUX` | `$C1F8` | 11 |  |
| 33 | `6 SHIPS` | `6 VAISSEAUX` | `$C204` | 11 |  |
| 34 | `ASTRO BATTLES` | `BATAILLES ASTRALES` | `$C210` | 18 |  |
| 35 | `GALAXIANS` | `GALAXIENS` | `$C223` | 9 |  |
| 36 | `LASER ATTACK` | `ATTAQUE LASER` | `$C22D` | 13 |  |
| 37 | `SPACE WARP` | `CREATURE SPATIALE` | `$C23B` | 17 |  |
| 38 | `FLAG SHIP` | `VAISSEAU AMIRAL` | `$C24D` | 15 |  |
| 39 | `1 PLAYER` | `1 JOUEUR` | `$C25D` | 8 |  |
| 40 | `2 PLAYERS` | `2 JOUEURS` | `$C266` | 9 |  |
| 41 | `INSERT COIN` | `DEPOSER JETON` | `$C270` | 13 |  |
| 42 | one space | one space | `$C27E` | 1 | Program-2 structural record; preserved exactly |
| 43 | one space | one space | `$C280` | 1 | Program-2 structural record; preserved exactly |
| 44 | `$09` | `$09` | `$C282` | 1 | Program-2 structural record; preserved exactly |
| 45 | `$0A,$0B,$09,$0D,$0E` | `$0A,$0B,$09,$0D,$0E` | `$C284` | 5 | Program-2 structural record; preserved exactly |
| 46 | `$0C,$0B,$09,$0D,$0F` | `$0C,$0B,$09,$0D,$0F` | `$C28A` | 5 | Program-2 structural record; preserved exactly |
| 47 | `$0C` | `$0C` | `$C290` | 1 | Program-2 structural record; preserved exactly |
| 48 | `SAME PLAYER UP` | `LE MEME JOUEUR` | `$C292` | 14 |  |
| 49 | `CREDIT SHIPS[` | `CREDIT VAISSEAUX[` | `$C2A1` | 17 | Program-2-only credit record |
| 50 | `$5C,"1981 MIDWAY MFG CO"` | `$5C,"1981 MIDWAY MFG CO"` | `$C2B3` | 19 | Program-2-only copyright record |
| 51 | `ALL RIGHTS RESERVED` | `TOUS DROITS RESERVES` | `$C2C7` | 20 | Program-2-only rights record |

## Speech translation

The translator searches 36 sorted Program-2 keys. It provides 34 local French records, suppresses `SPK_SPACE` because the French rank records already contain `de l'espace`, and reuses the resident language-neutral laugh.

All 34 local records are copied byte-for-byte from the  Program-1 French X11. Their 901 encoded payload bytes, including bits 6-7, are preserved exactly. The French wording below is a working orthographic transcription reconstructed from the SC-01 streams and selector semantics; the encoded ROM bytes remain authoritative.

| ID | Source label | Resident key | English fragment | French working transcription | Notes |
| ---: | --- | ---: | --- | --- | --- |
| 0 | `SPK_INSERT` | `$115D` | Insert coin | Déposez jeton. |  |
| 1 | `SPK_GORF` | `$116D` | I am the Gorfian Empire | Je suis l'empire gorfien. |  |
| 2 | `SPK_SPACE` | `$1185` | Space | Suppressed; French rank records already include `de l'espace`. | Null translation (`$0000`), matching  Program-1 French |
| 3 | `SPK_CONQUER` | `$118C` | Gorfians conquer another galaxy | Les Gorfiens ont conquis une autre galaxie. |  |
| 4 | `SPK_TRY` | `$11A8` | Try again; I devour your coins | Essayez encore ; je dévore la monnaie. |  |
| 5 | `SPK_LONG` | `$11C7` | Long live Gorf | Longue vie, Gorf. |  |
| 6 | `SPK_ROBOTS` | `$11D7` | Gorfian robots, attack! Attack! | Robots gorfiens, attaque ! Attaque ! |  |
| 7 | `SPK_BADMOVE` | `$11F6` | Bad move | Mauvais mouvement. |  |
| 8 | `SPK_HAHA` | `$1200` | Ha ha ha ha | Language-neutral resident laugh | Uses resident language-neutral laugh |
| 9 | `SPK_ESCAPE` | `$120A` | You cannot escape the Gorfian robots | Vous ne pouvez échapper aux robots de Gorf. |  |
| 10 | `SPK_GOTYOU` | `$122E` | Got you | Je vous ai eu. |  |
| 11 | `SPK_NICE` | `$1237` | Nice shot | Bien visé. |  |
| 12 | `SPK_TOOBAD` | `$1243` | Too bad | Bien essayé. |  |
| 13 | `SPK_PRIS` | `$124B` | Gorfians take no prisoners | Les Gorfiens ne font pas de prisonniers. |  |
| 14 | `SPK_CADET` | `$1264` | Cadet | Cadet de l'espace |  |
| 15 | `SPK_CAPT` | `$126B` | Captain | Capitaine de l'espace |  |
| 16 | `SPK_COLONEL` | `$1274` | Colonel | Colonel de l'espace |  |
| 17 | `SPK_GENERAL` | `$127B` | General | Général de l'espace |  |
| 18 | `SPK_WARRIOR` | `$1284` | Warrior | Guerrier de l'espace |  |
| 19 | `SPK_AVENGER` | `$128D` | Avenger | Suprême héros de l'espace |  |
| 20 | `SPK_PROMOTE` | `$1298` | You have been promoted to | Vous avez été promu |  |
| 21 | `SPK_SOME` | `$12B2` | Some galactic defender you are | Quelle sorte de protecteur de la galaxie êtes-vous ? |  |
| 22 | `SPK_BITE` | `$12CE` | Bite the dust | Allez mordre la poussière. |  |
| 23 | `SPK_HAIL` | `$12DB` | All hail the supreme Gorfian Empire | Vive le suprême empire gorfien. |  |
| 24 | `SPK_ENEMY` | `$12FC` | Another enemy ship destroyed | Un autre vaisseau ennemi détruit. |  |
| 25 | `SPK_BETCHA` | `$1317` | Your end draws near | Votre fin est proche. |  |
| 26 | `UNNAMED_A985` | `$A985` | Next time will be harder, but for now | La prochaine fois, ce sera plus difficile, mais dans l'entretemps... | Main disassembly source label remains unnamed; X11 source now uses a semantic alias |
| 27 | `UNNAMED_A9A8` | `$A9A8` | In the Gorfian chronicles | Votre nom sera dans le journal gorfien. | Main disassembly source label remains unnamed; X11 source now uses a semantic alias |
| 28 | `UNNAMED_A9C1` | `$A9C1` | For hitting my flagship | Pour avoir descendu mon vaisseau amiral. | Main disassembly source label remains unnamed; X11 source now uses a semantic alias |
| 29 | `SPK_PUSH` | `$B3BE` | Push a player button | Pressez le bouton joueur. |  |
| 30 | `SPK_DOOM` | `$B3D4` | You will meet a Gorfian doom | Vous connaîtrez une fin gorfienne. |  |
| 31 | `SPK_SURVIVAL` | `$B3EF` | Survival is impossible | Toute survie est hors de question. |  |
| 32 | `SPK_ROBOWARRIOR` | `$B405` | Robot warriors, seek and destroy the | Guerriers robots, poursuivez et détruisez le... |  |
| 33 | `SPK_GORFIAN` | `$B426` | My Gorfian robots are unbeatable | Mes robots gorfiens sont imbattables. |  |
| 34 | `SPK_IAM` | `$B449` | I am a Gorfian consciousness | Je suis la conscience gorfienne. |  |
| 35 | `SPK_PREPARE` | `$B465` | Prepare yourself for annihilation | Votre destruction est proche. |  |

## Phrase selection

Program 2 composes speech from the fragments above; it does not use a separate numeric phrase-ID table. `RANK` is one of the six resident rank selections. Because the translated `SPK_SPACE` key is null, each French rank record supplies the complete spoken rank boundary itself.

The selector names and path indexes match the English map in [`../../docs/SPEECH_MAP.md`](../../docs/SPEECH_MAP.md).

| Selector or path | Resident composition | English result | French working result | Notes |
| --- | --- | --- | --- | --- |
| `phrases[0]` | `SPK_INSERT` | Insert coin | Déposez jeton. | Attract table |
| `phrases[1]` | `SPK_GORF` | I am the Gorfian Empire | Je suis l'empire gorfien. | Attract table |
| `phrases[2]` | `SPK_LONG` | Long live Gorf | Longue vie, Gorf. | Attract table |
| `phrases[3]` | `SPK_INSERT` | Insert coin | Déposez jeton. | Intentional duplicate |
| `SPKCOIN[0]` | `SPK_PUSH` | Push a player button | Pressez le bouton joueur. | Coin/start prompt |
| `SPKCOIN[1]` | `SPK_LONG` | Long live Gorf | Longue vie, Gorf. | Coin/start alternate |
| `_SPKGENERIC[0]` | `SPK_TOOBAD` + `SPK_SPACE` + `RANK` + `SPK_CONQUER` | Too bad [rank]. Gorfians conquer another galaxy | Bien essayé, [rang français]. Les Gorfiens ont conquis une autre galaxie. | Random generic taunt |
| `_SPKGENERIC[1]` | `SPK_TOOBAD` + `SPK_SPACE` + `RANK` + `SPK_TRY` | Too bad [rank]. Try again; I devour your coins | Bien essayé, [rang français]. Essayez encore ; je dévore la monnaie. | Random generic taunt |
| `_SPKGENERIC[2]` | `SPK_TOOBAD` + `SPK_SPACE` + `RANK` + `SPK_ESCAPE` | Too bad [rank]. You cannot escape the Gorfian robots | Bien essayé, [rang français]. Vous ne pouvez échapper aux robots de Gorf. | Random generic taunt |
| `_SPKGENERIC[3]` | `SPK_TOOBAD` + `SPK_SPACE` + `RANK` + `SPK_GORF` | Too bad [rank]. I am the Gorfian Empire | Bien essayé, [rang français]. Je suis l'empire gorfien. | Random generic taunt |
| `_SPKGENERIC[4]` | `SPK_TOOBAD` + `SPK_SPACE` + `RANK` + `SPK_HAIL` | Too bad [rank]. All hail the supreme Gorfian Empire | Bien essayé, [rang français]. Vive le suprême empire gorfien. | Random generic taunt |
| `_SPKGENERIC[5]` | `SPK_BITE` + `SPK_SPACE` + `RANK` + `SPK_CONQUER` | Bite the dust [rank]. Gorfians conquer another galaxy | Allez mordre la poussière, [rang français]. Les Gorfiens ont conquis une autre galaxie. | Random generic taunt |
| `_SPKGENERIC[6]` | `SPK_BITE` + `SPK_SPACE` + `RANK` + `SPK_TRY` | Bite the dust [rank]. Try again; I devour your coins | Allez mordre la poussière, [rang français]. Essayez encore ; je dévore la monnaie. | Random generic taunt |
| `_SPKGENERIC[7]` | `SPK_BITE` + `SPK_SPACE` + `RANK` + `SPK_ESCAPE` | Bite the dust [rank]. You cannot escape the Gorfian robots | Allez mordre la poussière, [rang français]. Vous ne pouvez échapper aux robots de Gorf. | Random generic taunt |
| `_SPKGENERIC[8]` | `SPK_BITE` + `SPK_SPACE` + `RANK` + `SPK_GORF` | Bite the dust [rank]. I am the Gorfian Empire | Allez mordre la poussière, [rang français]. Je suis l'empire gorfien. | Random generic taunt |
| `_SPKGENERIC[9]` | `SPK_BITE` + `SPK_SPACE` + `RANK` + `SPK_HAIL` | Bite the dust [rank]. All hail the supreme Gorfian Empire | Allez mordre la poussière, [rang français]. Vive le suprême empire gorfien. | Random generic taunt |
| `_SPKINSULT[0]` | `SPK_HAHA` | Ha ha ha ha | Language-neutral resident laugh | Standalone insult |
| `_SPKINSULT[1]` | `SPK_ENEMY` | Another enemy ship destroyed | Un autre vaisseau ennemi détruit. | Standalone insult |
| `_SPKINSULT[2]` | `SPK_BETCHA` + `SPK_SPACE` + `RANK` | Your end draws near [rank] | Votre fin est proche, [rang français]. | Insult followed by rank |
| `_SPKINSULT[3]` | `SPK_BADMOVE` + `SPK_SPACE` + `RANK` | Bad move [rank] | Mauvais mouvement, [rang français]. | Insult followed by rank |
| `_SPKINSULT[4]` | `SPK_GOTYOU` + `SPK_SPACE` + `RANK` | Got you [rank] | Je vous ai eu, [rang français]. | Insult followed by rank |
| `_SPKINSULT[5]` | `SPK_SOME` + `SPK_SPACE` + `RANK` | Some galactic defender you are [rank] | Quelle sorte de protecteur de la galaxie êtes-vous, [rang français] ? | Insult followed by rank |
| `SPEAKSTART[0]` | `SPK_GORF` | I am the Gorfian Empire | Je suis l'empire gorfien. | Random game-start path |
| `SPEAKSTART[1]` | `SPK_ROBOTS` | Gorfian robots, attack! Attack! | Robots gorfiens, attaque ! Attaque ! | Random game-start path |
| `SPEAKSTART[2]` | `SPK_DOOM` + `SPK_SPACE` + `RANK` | You will meet a Gorfian doom [rank] | Vous connaîtrez une fin gorfienne, [rang français]. | Random game-start path |
| `SPEAKSTART[3]` | `SPK_SURVIVAL` + `SPK_SPACE` + `RANK` | Survival is impossible [rank] | Toute survie est hors de question, [rang français]. | Random game-start path |
| `SPEAKSTART[4]` | `SPK_ESCAPE` | You cannot escape the Gorfian robots | Vous ne pouvez échapper aux robots de Gorf. | Random game-start path |
| `SPEAKSTART[5]` | `SPK_ROBOWARRIOR` + `SPK_SPACE` + `RANK` | Robot warriors, seek and destroy the [rank] | Guerriers robots, poursuivez et détruisez le [rang français]. | Random game-start path |
| `SPEAKSTART[6]` | `SPK_GORFIAN` | My Gorfian robots are unbeatable | Mes robots gorfiens sont imbattables. | Random game-start path |
| `SPEAKSTART[7]` | `SPK_IAM` | I am a Gorfian consciousness | Je suis la conscience gorfienne. | Random game-start path |
| `SPEAKSTART[8]` | `SPK_PREPARE` + `SPK_SPACE` + `RANK` | Prepare yourself for annihilation [rank] | Votre destruction est proche, [rang français]. | Random game-start path |
| `SPEAKSTART[9]` | `SPK_PRIS` | Gorfians take no prisoners | Les Gorfiens ne font pas de prisonniers. | Random game-start path |
| `Promotion pattern` | `SPK_PROMOTE` + `SPK_SPACE` + `RANK` | You have been promoted to [rank] | Vous avez été promu [rang français]. | Compound rank announcement |
| `Flagship sequence` | `UNNAMED_A985` + `UNNAMED_A9A8` + `UNNAMED_A9C1` | Next time will be harder, but for now; in the Gorfian chronicles; for hitting my flagship | La prochaine fois, ce sera plus difficile, mais dans l'entretemps... Votre nom sera dans le journal gorfien. Pour avoir descendu mon vaisseau amiral. | Three contiguous upper-ROM records |

## Queue protection

Program 2's eight-entry ring buffer does not prevent the writer from overtaking the reader. `WaitForSpeechQueueSlot` reserves one empty entry before calling the resident queue routine. Interrupts remain enabled while it waits, allowing SC-01 playback to advance during compound announcements.

## ROM trailer

The  Program-1 French and German X11 images share the same 13-byte identification record at `$CFF3-$CFFF`:

```text
00 "GORF" 00 "DNA" 00 12 15 80
```

`$CFF2` is not part of that common record. German stores `$00` there; French leaves it erased as `$FF`. The Program-2 French source deliberately preserves the French `$FF` value.

## Build

Linux:

```sh
./build.sh -f
```

Windows:

```bat
build.bat -f
```

The build assembles `src/french/FRENCH_X11.asm` as the standalone project artifact `roms/french.x11`. It then creates `roms/gorfpgm1f.zip` using the member names expected by stock MAME:

```text
gorf_a.x1
gorf_b.x2
gorf_c.x3
gorf_d.x4
gorf_e.x5
gorf_f.x6
gorf_g.x7
gorf_h.x8
french_gorf.x11
sc01.bin
```

`french_gorf.x11` is only the compatibility member name inside the archive; the retained standalone artifact remains `roms/french.x11`. `sc01.bin` is required so every produced Gorf archive is self-contained for speech.

## MAME compatibility

Stock MAME provides `gorfpgm1f`, not a Program-2 French clone. The project therefore packages rebuilt Program-2 CPU ROMs using the Program-1 French member names and aliases the Program-2 French X11 as `french_gorf.x11`.

Run:

```text
mame -window -skip_gameinfo -rompath roms gorfpgm1f
```

Select `Foreign` for the cabinet Language option. Audit warnings are expected because the driver describes the catalogued Program-1 French set while the archive contains rebuilt Program-2 CPU ROMs and the adapted X11 image.

## Verification status

Static audit of this revision establishes:

- 52 Program-2 display records ending immediately before the French speech block at `$C2DC`;
- 34 local French speech records copied exactly from their  Program-1 source records;
- 901 preserved encoded French SC-01 payload bytes;
- 36 sorted Program-2 speech keys and 36 parallel targets;
- null translation for `SPK_SPACE` and resident reuse for `SPK_HAHA`;
- `$C000` translator entry and `$CC00 -> $1769` foreign-input return;
- French `$CFF2 = $FF` and the shared 13-byte identification record at `$CFF3-$CFFF`.

MAME runtime testing has covered attract mode, coin-up, gameplay, display labels, speech, and exit. The Program-2 screens differ where Program 2 itself uses different prompt composition or additional copyright records; gameplay has run without the speech clicks, stuck buzzes, or exit buzz that exposed earlier X11 failures.
