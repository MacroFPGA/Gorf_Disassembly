<!-- README.md -->
# Gorf Program-2 German X11 language ROM

This directory contains the German X11 language ROM adapted for Gorf Program 2. The 4 KB image combines the original German display and SC-01 speech data with the interfaces and resident addresses required by Program 2.

This is a Program-2 build. A Program-1 X11 image cannot be used unchanged because the resident speech addresses, speech queue entry point, message indexes, and foreign coin/input path differ.

The complete display-string and speech mapping is documented in [`SPEECH_MAP.md`](SPEECH_MAP.md).

## X11 interface

The X11 ROM occupies `$C000-$CFFF` on the 44 KB foreign ROM/RAM board. Gorf Program 2 uses three entry points:

| Address | Entry | Purpose |
| ---: | --- | --- |
| `$C000` | `X11Entry` | Translates a Program-2 English speech-primitive address in `DE` to the corresponding German primitive. |
| `$C003` | `GermanMessageTable` | Base of the 52 length-prefixed Program-2 display records. |
| `$CC00` | `ForeignCoinInputEntry` | Returns foreign-mode coin and input processing to the resident Program-2 routine at `$1769`. |

The `$CC00` entry is required by Program 2. When the Language DIP selects Foreign, the resident program branches to `$CC00` before reading the coin and start inputs. An X11 image without this entry executes unused `$FF` padding and does not complete the normal attract, coin-up, and game-start sequence.

## Display messages

Program 2 selects display text by a zero-based index. Each X11 record consists of a one-byte payload length followed by that many bytes:

```text
length, payload...
```

The German table contains all 52 records expected by Program 2. The ordering is not the same as the original Program-1 German table. Records 42 through 47 are blank or binary control records and are preserved in the exact Program-2 positions.

Printable German text uses the character repertoire available to the game. Umlauts are therefore written as `AE`, `OE`, and `UE`. The literal `$5B` and `$5C` character codes used by the resident display data are retained where required.

See [`SPEECH_MAP.md`](SPEECH_MAP.md#display-message-map) for every English and German record, including its index, address, and payload length.

## Speech translation

Program 2 passes the address of an English speech primitive in `DE` and jumps to `$C000`. `TranslateSpeechPrimitive` searches a sorted table of 36 Program-2 addresses and selects the parallel German target.

The translation set contains:

- 34 German length-prefixed SC-01 records;
- one suppressed English `SPACE` primitive because each German rank already includes `Raum`;
- one language-neutral laugh that continues to use the resident Program-2 record.

The German speech records retain 1,032 encoded SC-01 payload bytes from the German ROM data. The upper two bits remain part of the game's inflection encoding and must not be stripped when rebuilding the ROM.

### Speech queue guard

Program 2 stores speech pointers in an eight-entry ring buffer at `$D112-$D121`. Its resident enqueue routine does not test whether the next write would overtake the reader. The longer German primitives can keep the consumer active long enough for a burst of compound speech to overrun that queue.

`WaitForSpeechQueueSlot` checks the resident read and write pointers before dispatching a translated primitive. It reserves one entry so equal pointers continue to mean an empty queue, matching the interrupt-driven consumer. Interrupts remain enabled while the routine waits, allowing playback to advance normally.

The guard is required when the complete German mapping is active, particularly for compound phrases that append the player's translated rank.

## Build

The Windows and Linux build scripts support the German target with `-g`:

```bat
build.bat -g
```

```sh
./build.sh -g
```

The German build:

1. assembles `src/Gorf_Disassembly.asm`;
2. assembles `src/german/GERMAN_X11.asm` as a separate 4 KB image;
3. writes the Program-2 CPU ROMs as `873a.x1` through `873h.x8`;
4. writes `roms/german.x11`;
5. creates `roms/gorfpgm1g.zip` and includes `sc01.bin` when available.

Running either script without `-g` retains the normal `gorf-a.bin` through `gorf-h.bin` output and creates `gorf.zip`.

## MAME

The Program-2 German build has been runtime-tested with MAME 0.289:

```text
mame -window -skip_gameinfo -rompath roms gorfpgm1g
```

Set the cabinet Language option to `Foreign`.

MAME identifies `gorfpgm1g` as the original Program-1 German set, so checksum warnings are expected when the archive contains the rebuilt Program-2 CPU ROMs and adapted X11 image.

## Verification

The verified X11 image has the following values:

- Size: 4096 bytes
- CRC-32: `D9BB9F11`
- SHA-1: `D19DDA593369988BE931A54149DF88C0411DD05D`

Runtime verification covered the attract sequence, German display text, German speech, coin-up, player selection, and game start under MAME 0.289. An independent `build.sh -g` build produced a working archive from the source.
