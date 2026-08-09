#!/usr/bin/env bash
# build.sh
set -euo pipefail

readonly ROM_SIZE=$((0x1000))
readonly SOURCE_NAME="Gorf_Disassembly.asm"
readonly ENGLISH_ZIP_NAME="gorf.zip"
readonly GERMAN_ZIP_NAME="gorfpgm1g.zip"
readonly REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly SOURCE_DIR="$REPO_ROOT/src"
readonly BUILD_DIR="$SOURCE_DIR/zout"
readonly ROMS_DIR="$REPO_ROOT/roms"
readonly SOURCE_FILE="$SOURCE_DIR/$SOURCE_NAME"
readonly SOURCE_STEM="${SOURCE_NAME%.asm}"
readonly CIM_FILE="$BUILD_DIR/$SOURCE_STEM.cim"
readonly LST_FILE="$BUILD_DIR/$SOURCE_STEM.lst"
readonly SC01_FILE="$ROMS_DIR/sc01.bin"

# German specific paths
readonly GERMAN_SOURCE="$SOURCE_DIR/german/GERMAN_X11.asm"
readonly GERMAN_OUT_FILE="$ROMS_DIR/german.x11"

# Standard English ROM array names
readonly -a ENGLISH_ROM_NAMES=(
    "gorf-a.bin" "gorf-b.bin" "gorf-c.bin" "gorf-d.bin"
    "gorf-e.bin" "gorf-f.bin" "gorf-g.bin" "gorf-h.bin"
)

# German Alternate ROM array names
readonly -a GERMAN_ROM_NAMES=(
    "873a.x1" "873b.x2" "873c.x3" "873d.x4"
    "873e.x5" "873f.x6" "873g.x7" "873h.x8"
)

readonly -a ROM_ADDRESSES=(
    0x0000 0x1000 0x2000 0x3000
    0x8000 0x9000 0xA000 0xB000
)

# Global configuration variable controlled by arguments
BUILD_GERMAN=false
ZIP_NAME=""
ZIP_FILE=""

# Dynamically assigned pointer array to track active file list
ROM_NAMES=() 

log() {
    printf '%s\n' "$*"
}

fail() {
    printf 'ERROR: %s\n' "$*" >&2
    exit 1
}

require_command() {
    command -v "$1" >/dev/null 2>&1 || fail "Required command not found: $1"
}

resolve_zmac() {
    local candidate
    if [[ -n "${ZMAC:-}" ]]; then
        if [[ "$ZMAC" == */* ]]; then
            [[ -x "$ZMAC" ]] || fail "ZMAC is not executable: $ZMAC"
            printf '%s\n' "$ZMAC"
        else
            candidate="$(command -v "$ZMAC" 2>/dev/null)" || fail "ZMAC command not found: $ZMAC"
            printf '%s\n' "$candidate"
        fi
        return
    fi

    candidate="$REPO_ROOT/tools/zmac"
    if [[ -x "$candidate" ]]; then
        printf '%s\n' "$candidate"
        return
    fi

    candidate="$(command -v zmac 2>/dev/null)" || fail "zmac was not found. Install it in PATH, place it at tools/zmac, or set ZMAC=/path/to/zmac."
    printf '%s\n' "$candidate"
}

prepare_output_directories() {
    local name
    rm -rf -- "$BUILD_DIR"
    mkdir -p -- "$BUILD_DIR" "$ROMS_DIR"
    
    # Clean up files matching both potential naming schemas
    for name in "${ENGLISH_ROM_NAMES[@]}" "${GERMAN_ROM_NAMES[@]}"; do
        rm -f -- "$ROMS_DIR/$name"
    done
    rm -f -- "$GERMAN_OUT_FILE"
    rm -f -- "$ROMS_DIR/$ENGLISH_ZIP_NAME" "$ROMS_DIR/$GERMAN_ZIP_NAME"
}

assemble_source() {
    log "[2/4] Assembling $SOURCE_NAME"
    log "      zmac: $ZMAC_BIN"

    if "$ZMAC_BIN" --version 2>&1 | grep -q '1\.3'; then
        log "      Detected zmac v1.3 compatibility mode"
        (
            cd -- "$REPO_ROOT"
            "$ZMAC_BIN" -o "$CIM_FILE" -x "$LST_FILE" "$SOURCE_FILE"
        ) || fail "zmac v1.3 failed. Review the assembler output above."
    else
        log "      Detected modern zmac mode"
        (
            cd -- "$REPO_ROOT"
            "$ZMAC_BIN" -I "$REPO_ROOT" -I "$SOURCE_DIR" --od "$BUILD_DIR" --oo cim,lst "$SOURCE_FILE"
        ) || fail "zmac failed. Review the assembler output above."
    fi

    [[ -s "$CIM_FILE" ]] || fail "zmac did not create $CIM_FILE"
    [[ -s "$LST_FILE" ]] || fail "zmac did not create $LST_FILE"
    log "      image:   $CIM_FILE ($(stat -c '%s bytes' "$CIM_FILE"))"
    log "      listing: $LST_FILE"
}

assemble_german() {
    [[ -f "$GERMAN_SOURCE" ]] || fail "German source file not found: $GERMAN_SOURCE"
    log "[2.5/4] Assembling Optional German ROM: GERMAN_X11.asm"
    local german_tmp_cim="$BUILD_DIR/GERMAN_X11.cim"

    if "$ZMAC_BIN" --version 2>&1 | grep -q '1\.3'; then
        log "      Detected zmac v1.3 compatibility mode for German ROM"
        (
            cd -- "$REPO_ROOT"
            "$ZMAC_BIN" -o "$german_tmp_cim" -x "$BUILD_DIR/GERMAN_X11.lst" "$GERMAN_SOURCE"
        ) || fail "zmac v1.3 failed on German ROM."
    else
        log "      Detected modern zmac mode for German ROM"
        (
            cd -- "$REPO_ROOT"
            "$ZMAC_BIN" -I "$REPO_ROOT" -I "$SOURCE_DIR" -I "$SOURCE_DIR/german" --od "$BUILD_DIR" --oo cim,lst "$GERMAN_SOURCE"
        ) || fail "zmac failed on German ROM."
    fi

    [[ -s "$german_tmp_cim" ]] || fail "zmac did not create $german_tmp_cim"
    local german_size
    german_size="$(stat -c '%s' "$german_tmp_cim")"
    (( german_size == ROM_SIZE )) || fail "German ROM is $german_size bytes; expected $ROM_SIZE"
    cp -- "$german_tmp_cim" "$GERMAN_OUT_FILE"
    log "      german: $GERMAN_OUT_FILE ($(stat -c '%s bytes' "$GERMAN_OUT_FILE"))"
}

slice_roms() {
    local cim_size
    local index
    local rom_name
    local start_address
    local end_address
    local output_file
    local output_size

    cim_size="$(stat -c '%s' "$CIM_FILE")"
    (( cim_size > ROM_ADDRESSES[${#ROM_ADDRESSES[@]} - 1] )) || fail "Assembled image is too short for the Gorf ROM map: $cim_size bytes"

    log "[3/4] Splitting the CPU image into 4 KiB Gorf ROMs"
    log "      The video-memory gap at \$4000-\$7FFF is not packaged."

    for index in "${!ROM_NAMES[@]}"; do
        rom_name="${ROM_NAMES[$index]}"
        start_address="${ROM_ADDRESSES[$index]}"
        end_address=$((start_address + ROM_SIZE - 1))
        output_file="$ROMS_DIR/$rom_name"

        dd if=/dev/zero bs="$ROM_SIZE" count=1 status=none | tr '\000' '\377' > "$output_file"
        dd if="$CIM_FILE" of="$output_file" bs="$ROM_SIZE" skip="$((start_address / ROM_SIZE))" count=1 conv=notrunc status=none

        output_size="$(stat -c '%s' "$output_file")"
        (( output_size == ROM_SIZE )) || fail "$rom_name is $output_size bytes; expected $ROM_SIZE"

        printf '  %-12s CPU $%04X-$%04X %5d bytes\n' "$rom_name" "$start_address" "$end_address" "$output_size"
    done
}

create_zip() {
    local rom_name
    local -a zip_inputs=()

    for rom_name in "${ROM_NAMES[@]}"; do
        zip_inputs+=("$ROMS_DIR/$rom_name")
    done

    if [[ -f "$SC01_FILE" ]]; then
        zip_inputs+=("$SC01_FILE")
        log "      Including optional speech ROM: $SC01_FILE"
    else
        log "      Optional speech ROM not found; sc01.bin will not be included."
    fi

    if [[ "$BUILD_GERMAN" == true ]]; then
        if [[ -f "$GERMAN_OUT_FILE" ]]; then
            zip_inputs+=("$GERMAN_OUT_FILE")
            log "      Including optional German language ROM: $GERMAN_OUT_FILE"
        else
            fail "German ROM build was requested but file is missing: $GERMAN_OUT_FILE"
        fi
    fi

    (
        cd -- "$ROMS_DIR"
        zip -q -j -X "$ZIP_FILE" "${zip_inputs[@]}"
    ) || fail "Could not create $ZIP_FILE"

    [[ -s "$ZIP_FILE" ]] || fail "ZIP archive was not created: $ZIP_FILE"
    log "      archive: $ZIP_FILE ($(stat -c '%s bytes' "$ZIP_FILE"))"
}

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -g|--german)
                BUILD_GERMAN=true
                shift
                ;;
            -h|--help)
                log "Usage: $0 [options]"
                log "Options:"
                log "  -g, --german   Also assemble German language expansion and include in zip"
                log "  -h, --help     Display this help message"
                exit 0
                ;;
            *)
                fail "Unknown argument: $1. Use --help for usage details."
                ;;
        esac
    done
}

main() {
    local ZMAC_BIN
    parse_arguments "$@"

    # Configure names array depending on the argument flag evaluation
    if [[ "$BUILD_GERMAN" == true ]]; then
        ROM_NAMES=("${GERMAN_ROM_NAMES[@]}")
        ZIP_NAME="$GERMAN_ZIP_NAME"
    else
        ROM_NAMES=("${ENGLISH_ROM_NAMES[@]}")
        ZIP_NAME="$ENGLISH_ZIP_NAME"
    fi
    ZIP_FILE="$ROMS_DIR/$ZIP_NAME"

    [[ -f "$SOURCE_FILE" ]] || fail "Source file not found: $SOURCE_FILE"

    require_command dd
    require_command stat
    require_command tr
    require_command zip

    ZMAC_BIN="$(resolve_zmac)"

    log "Gorf ROM build"
    log "  source: $SOURCE_FILE"
    log "  output: $ROMS_DIR"
    log
    log "[1/4] Preparing clean build and ROM output"
    prepare_output_directories

    assemble_source

    if [[ "$BUILD_GERMAN" == true ]]; then
        assemble_german
    fi

    slice_roms

    log "[4/4] Creating $ZIP_NAME"
    create_zip

    log
    log "Build complete."
    if [[ "$BUILD_GERMAN" == true ]]; then
        log "  ROM files: $ROMS_DIR/873{a..h}.x{1..8}"
        log "  German ROM: $GERMAN_OUT_FILE"
    else
        log "  ROM files: $ROMS_DIR/gorf-{a..h}.bin"
    fi
    log "  MAME ZIP:  $ZIP_FILE"
}

main "$@"
