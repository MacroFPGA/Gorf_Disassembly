-- gorf_monitor_hud.lua

local H = {}
H.module_name = "hud"
H.api_version = 1
H.revision = "2.3.0-20260812"

H.colors = {
    panel = 0xFF05070A,
    border = 0xFFFF9800,
    heading = 0xFFFFA000,
    text = 0xFFF0F3F5,
    dim = 0xFF8E9AA3,
    value = 0xFF55D6FF,
    active = 0xFF7CFF6B,
    warning = 0xFFFFD54F,
    error = 0xFFFF6464,
    transparent = 0x00000000
}

H.page_order = { "important", "terse", "game", "audio", "video", "all" }

-- Compact 5x7 bitmap glyphs keep the HUD independent of MAME's global UI font
-- size. Lower-case input is rendered with the corresponding upper-case glyph.
H.font = {
    [" "] = { 0, 0, 0, 0, 0, 0, 0 },
    ["!"] = { 4, 4, 4, 4, 4, 0, 4 },
    ["#"] = { 10, 31, 10, 10, 31, 10, 0 },
    ["$"] = { 4, 15, 20, 14, 5, 30, 4 },
    ["%"] = { 24, 25, 2, 4, 8, 19, 3 },
    ["&"] = { 12, 18, 20, 8, 21, 18, 13 },
    ["'"] = { 4, 4, 8, 0, 0, 0, 0 },
    ["("] = { 2, 4, 8, 8, 8, 4, 2 },
    [")"] = { 8, 4, 2, 2, 2, 4, 8 },
    ["*"] = { 0, 10, 4, 31, 4, 10, 0 },
    ["+"] = { 0, 4, 4, 31, 4, 4, 0 },
    [","] = { 0, 0, 0, 0, 4, 4, 8 },
    ["-"] = { 0, 0, 0, 31, 0, 0, 0 },
    ["."] = { 0, 0, 0, 0, 0, 12, 12 },
    ["/"] = { 1, 2, 2, 4, 8, 8, 16 },
    ["0"] = { 14, 17, 19, 21, 25, 17, 14 },
    ["1"] = { 4, 12, 4, 4, 4, 4, 14 },
    ["2"] = { 14, 17, 1, 2, 4, 8, 31 },
    ["3"] = { 30, 1, 1, 14, 1, 1, 30 },
    ["4"] = { 2, 6, 10, 18, 31, 2, 2 },
    ["5"] = { 31, 16, 16, 30, 1, 1, 30 },
    ["6"] = { 6, 8, 16, 30, 17, 17, 14 },
    ["7"] = { 31, 1, 2, 4, 8, 8, 8 },
    ["8"] = { 14, 17, 17, 14, 17, 17, 14 },
    ["9"] = { 14, 17, 17, 15, 1, 2, 12 },
    [":"] = { 0, 12, 12, 0, 12, 12, 0 },
    [";"] = { 0, 12, 12, 0, 4, 4, 8 },
    ["<"] = { 2, 4, 8, 16, 8, 4, 2 },
    ["="] = { 0, 0, 31, 0, 31, 0, 0 },
    [">"] = { 8, 4, 2, 1, 2, 4, 8 },
    ["?"] = { 14, 17, 1, 2, 4, 0, 4 },
    ["@"] = { 14, 17, 23, 21, 23, 16, 14 },
    ["A"] = { 14, 17, 17, 31, 17, 17, 17 },
    ["B"] = { 30, 17, 17, 30, 17, 17, 30 },
    ["C"] = { 14, 17, 16, 16, 16, 17, 14 },
    ["D"] = { 30, 17, 17, 17, 17, 17, 30 },
    ["E"] = { 31, 16, 16, 30, 16, 16, 31 },
    ["F"] = { 31, 16, 16, 30, 16, 16, 16 },
    ["G"] = { 14, 17, 16, 23, 17, 17, 15 },
    ["H"] = { 17, 17, 17, 31, 17, 17, 17 },
    ["I"] = { 14, 4, 4, 4, 4, 4, 14 },
    ["J"] = { 7, 2, 2, 2, 2, 18, 12 },
    ["K"] = { 17, 18, 20, 24, 20, 18, 17 },
    ["L"] = { 16, 16, 16, 16, 16, 16, 31 },
    ["M"] = { 17, 27, 21, 21, 17, 17, 17 },
    ["N"] = { 17, 25, 25, 21, 19, 19, 17 },
    ["O"] = { 14, 17, 17, 17, 17, 17, 14 },
    ["P"] = { 30, 17, 17, 30, 16, 16, 16 },
    ["Q"] = { 14, 17, 17, 17, 21, 18, 13 },
    ["R"] = { 30, 17, 17, 30, 20, 18, 17 },
    ["S"] = { 15, 16, 16, 14, 1, 1, 30 },
    ["T"] = { 31, 4, 4, 4, 4, 4, 4 },
    ["U"] = { 17, 17, 17, 17, 17, 17, 14 },
    ["V"] = { 17, 17, 17, 17, 17, 10, 4 },
    ["W"] = { 17, 17, 17, 21, 21, 21, 10 },
    ["X"] = { 17, 17, 10, 4, 10, 17, 17 },
    ["Y"] = { 17, 17, 10, 4, 4, 4, 4 },
    ["Z"] = { 31, 1, 2, 4, 8, 16, 31 },
    ["["] = { 14, 8, 8, 8, 8, 8, 14 },
    ["\\"] = { 16, 8, 8, 4, 2, 2, 1 },
    ["]"] = { 14, 2, 2, 2, 2, 2, 14 },
    ["^"] = { 4, 10, 17, 0, 0, 0, 0 },
    ["_"] = { 0, 0, 0, 0, 0, 0, 31 },
    ["|"] = { 4, 4, 4, 4, 4, 4, 4 }
}

local function safe_property(object, name)
    local ok, value = pcall(function() return object[name] end)
    if ok then return value end
    return nil
end

local function hex(value, width)
    return string.format("%0" .. tostring(width or 2) .. "X", value or 0)
end

local function raw8(value)
    return value == nil and "--" or ("$" .. hex(value, 2))
end

local function raw16(value)
    return value == nil and "----" or ("$" .. hex(value, 4))
end

local function join_hex(values, maximum)
    local result = {}
    for index = 1, math.min(#values, maximum or #values) do
        result[#result + 1] = hex(values[index], 4)
    end
    return #result > 0 and table.concat(result, " ") or "--"
end

local function event_text(event)
    if not event then return "--" end
    return string.format("$%02X=$%02X %s", event.port, event.value, event.name or "")
end

local function trace_text(event)
    if not event then return "--" end
    local detail = event.detail and (" " .. event.detail) or ""
    return string.format("%04X>%04X %s%s", event.ip, event.target,
        event.name or "UNRESOLVED", detail)
end

local function trace_decode_text(event)
    if not event or type(event) ~= "table" then return "--" end
    local name_str = event.decoded_name or event.name or "UNRESOLVED"
    local preview_str = event.terse_stream_preview or ""
    if event.decoded_name then
        return string.format("%s %s [%s]", preview_str, name_str,
            event.decoded_source or event.target_class or "EXACT")
    end
    local nearest = event.nearest_symbol and ("; NEAR " .. event.nearest_symbol) or ""
    return string.format("%s %s%s", preview_str, name_str, nearest)
end

local function trace_annotation_text(event)
    if not event or not event.decoded_description then return nil end
    local prefix = event.description_source == "UNVERIFIED" and "HYP " or "NOTE "
    return prefix .. event.decoded_description
end

local function trace_context_text(event)
    if not event or not event.reconstructed_context then return "RECON CONTEXT --" end
    local offset = event.reconstructed_stream_offset and
        (" +$" .. hex(event.reconstructed_stream_offset, 2)) or ""
    return string.format("CTX %s%s", event.reconstructed_context, offset)
end

local function line(lines, text, color, swatch)
    lines[#lines + 1] = {
        text = tostring(text or ""), color = color or H.colors.text, swatch = swatch
    }
end

local function section(lines, text)
    if #lines > 0 then line(lines, "") end
    line(lines, text, H.colors.heading)
end

local function mission_text(game)
    return string.format("MISSION %s %s", raw8(game.MISSION), game.MISSION_NAME or "--")
end

local function rank_text(game)
    return string.format("RANK %s %s", raw8(game.SKILLFACTOR), game.RANK_NAME or "--")
end

local function phoneme_text(speech)
    local event = speech.last_phoneme
    if not event then return "--" end
    return string.format("$%02X %s", event.raw, event.display)
end

local function primitive_text(speech)
    if not speech.speaking_address then return "--" end
    return string.format("%s %s", raw16(speech.speaking_address),
        speech.speaking_primitive or "UNKNOWN")
end

local function queued_text(speech)
    if not speech.queued_address then return "--" end
    return string.format("%s %s", raw16(speech.queued_address), speech.queued_name or "UNKNOWN")
end

local function music_executed_text(music)
    local event = music.last_executed
    if not event then return "--" end
    return string.format("$%02X %s @%s", event.opcode, event.opcode_name, raw16(event.pc))
end

local function music_next_text(music)
    if music.next_opcode == nil then return raw16(music.next_pc) .. " BYTE --" end
    return string.format("%s $%02X %s", raw16(music.next_pc),
        music.next_opcode, music.next_opcode_name)
end

local function recent_audio_events(maximum)
    return H.gorf.core.ring_recent(H.gorf.state.audio_events, maximum)
end

local function sound_history_text(event)
    if not event then return "--" end
    if event.kind == "music1" or event.kind == "music2" then
        return string.format("M%d EXEC $%02X %s @%04X",
            event.engine, event.opcode, event.opcode_name, event.pc)
    end
    local chip = event.kind == "sound1" and "S1" or "S2"
    return string.format("%s $%02X=$%02X %s @%04X",
        chip, event.port, event.value, event.name or "", event.pc)
end

local function game_summary(lines, game, include_scores)
    line(lines, "GAME-OVER FLAG " .. raw8(game.DEMOMODE), H.colors.warning)
    line(lines, mission_text(game), H.colors.value)
    line(lines, string.format("PLAYERUP %s %s  NPLAY %s %s",
        raw8(game.PLAYERUP), game.PLAYER_NUMBER and ("P" .. game.PLAYER_NUMBER) or "--",
        raw8(game.NPLAYERS), game.PLAYER_COUNT and (game.PLAYER_COUNT .. "P") or "--"))
    line(lines, string.format("CREDITS %s (%d)  FRAC %s",
        raw8(game.COINSIN), game.COINSIN, raw8(game.COINFRAC)), H.colors.value)
    line(lines, string.format("COINS? %s  SLAM? %s", raw8(game.COINS), raw8(game.SLAM)), H.colors.dim)
    line(lines, rank_text(game), H.colors.value)
    line(lines, string.format("BASE P1 %s P2 %s RIP %s",
        raw8(game.P1FBCTR), raw8(game.P2FBCTR), raw8(game.RIP)))
    if include_scores then
        line(lines, string.format("SCORE %s / %s", game.P1_SCORE, game.P2_SCORE), H.colors.value)
    end
end

function H.layout_important(snapshot)
    local lines = {}
    local terse, game, speech = snapshot.terse, snapshot.game, snapshot.speech
    local last = terse.last
    section(lines, "GAME")
    game_summary(lines, game, false)

    section(lines, "VOTRAX")
    line(lines, "SPEAKING " .. (speech.speaking or "--"), H.colors.value)
    line(lines, "LAST SPOKEN " .. (speech.last_spoken or "--"))
    line(lines, "QUEUED " .. queued_text(speech), H.colors.dim)

    section(lines, "MUSIC")
    line(lines, "M1 EXEC " .. music_executed_text(snapshot.music[1]), H.colors.value)
    line(lines, "M2 EXEC " .. music_executed_text(snapshot.music[2]), H.colors.value)

    section(lines, "TERSE")
    line(lines, string.format("OBSERVED %d  %.0f W/S", terse.total_words, terse.word_rate), H.colors.active)
    line(lines, "WORD " .. (last and (raw16(last.target) .. " " .. last.name) or "--"), H.colors.value)
    line(lines, "ARG " .. (last and last.detail or "--"), H.colors.dim)
    if last and trace_annotation_text(last) then
        line(lines, trace_annotation_text(last), H.colors.warning)
    end
    line(lines, "CTX " .. (last and last.reconstructed_context or "--"), H.colors.dim)
    return lines
end

function H.layout_all(snapshot)
    local lines = {}
    local terse = snapshot.terse
    local game, speech = snapshot.game, snapshot.speech
    local last = terse.last
    section(lines, "GAME")
    game_summary(lines, game, true)

    section(lines, "VOTRAX")
    line(lines, "SPEAKING " .. (speech.speaking or "--"), H.colors.value)
    line(lines, "PRIMITIVE " .. primitive_text(speech), H.colors.dim)
    line(lines, "LAST SPOKEN " .. (speech.last_spoken or "--"))
    line(lines, "QUEUED " .. queued_text(speech), H.colors.dim)
    line(lines, string.format("PH %s  LEFT %s", phoneme_text(speech), raw8(speech.remaining)))

    section(lines, "MUSIC")
    line(lines, "M1 EXEC " .. music_executed_text(snapshot.music[1]), H.colors.value)
    line(lines, "M1 NEXT " .. music_next_text(snapshot.music[1]), H.colors.dim)
    line(lines, "M2 EXEC " .. music_executed_text(snapshot.music[2]), H.colors.value)
    line(lines, "M2 NEXT " .. music_next_text(snapshot.music[2]), H.colors.dim)
    line(lines, "CHIP1 " .. event_text(snapshot.sound[1].last), H.colors.dim)
    line(lines, "CHIP2 " .. event_text(snapshot.sound[2].last), H.colors.dim)

    section(lines, "TERSE")
    line(lines, string.format("OBSERVED %d  %.0f W/S", terse.total_words, terse.word_rate), H.colors.active)
    line(lines, string.format("LAST STREAM %s TARGET %s",
        last and raw16(last.ip) or "----", last and raw16(last.target) or "----"), H.colors.value)
    line(lines, string.format("NEXT BC %s DISPATCH PC %s",
        last and raw16(last.next_bc) or "----",
        last and raw16(last.dispatcher_pc) or "----"), H.colors.dim)
    line(lines, "WORD " .. (last and (raw16(last.target) .. " " .. last.name) or "--"))
    line(lines, "ARG " .. (last and last.detail or "--"), H.colors.dim)
    if last and trace_annotation_text(last) then
        line(lines, trace_annotation_text(last), H.colors.warning)
    end
    line(lines, "CTX " .. (last and last.reconstructed_context or "--"), H.colors.value)
    line(lines, string.format("PS %d IX %d C %d L %d D %d ? %d",
        terse.reconstructed_parameter_depth, terse.reconstructed_return_cells,
        terse.reconstructed_call_depth, terse.reconstructed_loop_depth,
        terse.reconstructed_return_data_depth,
        terse.reconstructed_unknown_return_depth), H.colors.dim)
    line(lines, "RECENT OBSERVED", H.colors.heading)
    local recent = H.gorf.recent(10)
    for index = 1, 10 do
        local event = recent[index]
        line(lines, trace_text(event), event and event.kind == "call" and H.colors.value or H.colors.text)
    end
    return lines
end

function H.layout_terse(snapshot)
    local lines = {}
    local terse = snapshot.terse
    local last = terse.last
    line(lines, string.format("OBSERVED %d WORDS", terse.total_words), H.colors.active)
    line(lines, string.format("RATE %.0f W/S  LAST FRAME %d", terse.word_rate, terse.frame_words), H.colors.value)

    section(lines, "DISPATCH")
    line(lines, "LAST STREAM " .. (last and raw16(last.ip) or "----"), H.colors.value)
    line(lines, "NEXT BC " .. (last and raw16(last.next_bc) or "----"), H.colors.dim)
    line(lines, "DISPATCH PC " .. (last and raw16(last.dispatcher_pc) or "----"))
    line(lines, "TARGET " .. (last and raw16(last.target) or "--"), H.colors.value)
    line(lines, "WORD " .. (last and last.name or "--"))
    line(lines, "TARGET CLASS " .. (last and last.target_class or "--"), H.colors.dim)
    line(lines, "DECODE " .. (last and trace_decode_text(last) or "--"), H.colors.dim)
    if last and trace_annotation_text(last) then
        line(lines, trace_annotation_text(last), H.colors.warning)
    end
    line(lines, "ARG " .. (last and last.detail or "--"),
        last and last.detail and H.colors.warning or H.colors.dim)

    section(lines, "TERSE STACK AT DISPATCH")
    line(lines, string.format("SP %s DEPTH %d", last and raw16(last.sp) or "----",
        terse.reconstructed_parameter_depth), H.colors.value)
    line(lines, "TOP " .. (last and join_hex(last.stack, 4) or "--"), H.colors.dim)
    line(lines, string.format("IX %s CELLS %d", last and raw16(last.ix) or "----",
        terse.reconstructed_return_cells), H.colors.value)
    line(lines, "IY " .. (last and raw16(last.iy) or "----"), H.colors.dim)
    line(lines, "CONTEXT " .. (last and last.reconstructed_context or "--"), H.colors.dim)
    line(lines, string.format("TYPED C %d L %d D %d ? %d",
        terse.reconstructed_call_depth, terse.reconstructed_loop_depth,
        terse.reconstructed_return_data_depth,
        terse.reconstructed_unknown_return_depth))
    for slot = 1, 3 do
        local frame = terse.reconstructed_call_stack[slot]
        line(lines, frame and string.format("C%d %s RET %s", slot, frame.name,
            raw16(frame.return_address)) or "--",
            frame and H.colors.value or H.colors.dim)
    end
    local loop = terse.reconstructed_loop_stack[1]
    line(lines, loop and string.format("L1 I %s/%s AT %s",
        raw16(loop.index), raw16(loop.limit), raw16(loop.loop_start)) or "L --",
        loop and H.colors.warning or H.colors.dim)
    local return_data = terse.reconstructed_return_data_stack[1]
    line(lines, return_data and string.format("D1 VALUE %s",
        raw16(return_data.value)) or "D --",
        return_data and H.colors.warning or H.colors.dim)
    local unknown = terse.reconstructed_unknown_return_stack[1]
    line(lines, unknown and string.format("?1 VALUE %s",
        raw16(unknown.value)) or "? --",
        unknown and H.colors.error or H.colors.dim)

    section(lines, "RECENT DISPATCHES")
    local recent = H.gorf.recent(10)
    for index = 1, 10 do
        local event = recent[index]
        line(lines, event and string.format("STREAM %s -> %s", raw16(event.ip), raw16(event.target)) or "--",
            event and event.kind == "call" and H.colors.value or H.colors.text)
        line(lines, trace_decode_text(event),
            event and event.decoded_name and H.colors.text or H.colors.warning)
        line(lines, trace_context_text(event), H.colors.dim)
    end
    return lines
end

function H.layout_game(snapshot)
    local lines = {}
    local game = snapshot.game
    section(lines, "GAME FLAGS")
    line(lines, "GAME-OVER FLAG " .. raw8(game.DEMOMODE), H.colors.warning)
    line(lines, mission_text(game), H.colors.value)
    line(lines, "MISSIONCTR " .. raw8(game.MISSIONCTR), H.colors.dim)
    line(lines, string.format("CRASH %s  AMBUSY %s", raw8(game.CRASHCTR), raw8(game.AMBUSY)), H.colors.dim)

    section(lines, "PLAYER")
    line(lines, string.format("PLAYERUP %s -> %s", raw8(game.PLAYERUP),
        game.PLAYER_NUMBER and ("P" .. game.PLAYER_NUMBER) or "--"), H.colors.value)
    line(lines, string.format("NPLAYERS %s -> %s", raw8(game.NPLAYERS),
        game.PLAYER_COUNT and (game.PLAYER_COUNT .. "P") or "--"), H.colors.value)
    line(lines, rank_text(game), H.colors.value)
    line(lines, string.format("BASE P1 %s  P2 %s", raw8(game.P1FBCTR), raw8(game.P2FBCTR)))
    line(lines, string.format("RIP %s  INITFB %s", raw8(game.RIP), raw8(game.INITFB)), H.colors.dim)
    line(lines, "P1 SCORE " .. game.P1_SCORE, H.colors.active)
    line(lines, "P2 SCORE " .. game.P2_SCORE, H.colors.active)

    section(lines, "COIN / CREDIT")
    line(lines, string.format("CREDITS %s (%d)", raw8(game.COINSIN), game.COINSIN), H.colors.value)
    line(lines, "COIN FRACTION " .. raw8(game.COINFRAC))
    line(lines, "COINS? EVENT " .. raw8(game.COINS))
    line(lines, "OLD PORT $10 " .. raw8(game.OLDCREDITS), H.colors.dim)
    line(lines, "SLAM? " .. raw8(game.SLAM), H.colors.dim)
    line(lines, "COCKTAIL " .. raw8(game.COCKTAIL), H.colors.dim)
    line(lines, "RNG " .. raw8(game.RND_SEED), H.colors.value)
    return lines
end

function H.layout_audio(snapshot)
    local lines = {}
    local speech = snapshot.speech
    section(lines, "VOTRAX SC-01")
    line(lines, "SPEAKING " .. (speech.speaking or "--"), H.colors.value)
    line(lines, "PRIMITIVE " .. primitive_text(speech), H.colors.dim)
    line(lines, "LAST SPOKEN " .. (speech.last_spoken or "--"))
    line(lines, "QUEUED " .. queued_text(speech), H.colors.dim)
    line(lines, "LAST PHONEME " .. phoneme_text(speech), H.colors.warning)
    line(lines, string.format("PHONE# %s  ONHOLD %s", raw8(speech.remaining), raw8(speech.on_hold)))
    line(lines, "TALKHERE " .. raw16(speech.talk_here), H.colors.dim)
    line(lines, string.format("TALKIN %s OUT %s", raw16(speech.talk_in), raw16(speech.talk_out)), H.colors.dim)
    local phonemes = H.gorf.core.ring_recent(H.gorf.state.speech.phonemes, 10)
    local names = {}
    for _, event in ipairs(phonemes) do names[#names + 1] = string.format("%02X", event.raw) end
    line(lines, table.concat(names, " "), H.colors.text)

    section(lines, "MUSIC CPU 1")
    local music = snapshot.music[1]
    line(lines, "LAST EXEC " .. music_executed_text(music), H.colors.value)
    line(lines, "NEXT PTR " .. music_next_text(music), H.colors.dim)
    line(lines, string.format("START %s  BOX %s", raw16(music.start_pc), raw8(music.soundbox)))
    line(lines, string.format("RAMBLE %s LIMIT %s", raw8(music.ramble), raw8(music.limit)), H.colors.dim)
    line(lines, string.format("NOTE %s MST %s", raw8(music.note_timer), raw8(music.mst)), H.colors.dim)

    section(lines, "MUSIC CPU 2")
    music = snapshot.music[2]
    line(lines, "LAST EXEC " .. music_executed_text(music), H.colors.value)
    line(lines, "NEXT PTR " .. music_next_text(music), H.colors.dim)
    line(lines, string.format("START %s  BOX %s", raw16(music.start_pc), raw8(music.soundbox)))
    line(lines, string.format("RAMBLE %s LIMIT %s", raw8(music.ramble), raw8(music.limit)), H.colors.dim)
    line(lines, string.format("NOTE %s MST %s", raw8(music.note_timer), raw8(music.mst)), H.colors.dim)

    section(lines, "ASTROCADE SOUND I/O")
    line(lines, "S1 " .. event_text(snapshot.sound[1].last))
    line(lines, "S2 " .. event_text(snapshot.sound[2].last))

    section(lines, "RECENT SPOKEN")
    local utterances = H.gorf.core.ring_recent(H.gorf.state.speech.utterances, 8)
    for index = 1, 8 do
        local utterance = utterances[index]
        line(lines, utterance and utterance.phrase or "--",
            utterance and H.colors.text or H.colors.dim)
    end

    section(lines, "RECENT AUDIO EXEC / I/O")
    local audio_events = recent_audio_events(10)
    for index = 1, 10 do
        line(lines, sound_history_text(audio_events[index]),
            audio_events[index] and H.colors.text or H.colors.dim)
    end
    return lines
end

function H.palette_device()
    local machine = H.gorf.runtime.machine
    local screens = safe_property(machine, "screens")
    if not screens then return nil end
    local screen = safe_property(screens, ":screen") or safe_property(screens, "screen")
    if not screen then
        for _, candidate in pairs(screens) do screen = candidate break end
    end
    local interface = screen and safe_property(screen, "palette")
    return interface and (safe_property(interface, "palette") or interface) or nil
end

function H.palette_color(index)
    if index == nil then return nil end
    local palette = H.palette_device()
    if not palette then return nil end
    local ok, color = pcall(function() return palette:entry_color(index) end)
    if not ok or type(color) ~= "number" then return nil end
    if (color & 0xFF000000) == 0 then color = color | 0xFF000000 end
    return color & 0xFFFFFFFF
end

local function palette_row(lines, side, pixel, port, value)
    local color = H.palette_color(value)
    local rgb = color and string.format(" #%06X", color & 0xFFFFFF) or ""
    line(lines, string.format("%s P%d PORT $%02X %s%s", side, pixel, port, raw8(value), rgb),
        value ~= nil and H.colors.text or H.colors.dim, color)
end

function H.layout_video(snapshot)
    local lines = {}
    local video = snapshot.video
    section(lines, "ASTROCADE VIDEO I/O")
    line(lines, "last " .. event_text(video.last), H.colors.value)
    line(lines, "from " .. (video.last and video.last.origin or "--"), H.colors.dim)
    section(lines, "PALETTE LEFT (PORTS $04-$07)")
    for pixel = 0, 3 do
        local port = 0x04 + pixel
        palette_row(lines, "L", pixel, port, video.ports[port])
    end
    section(lines, "PALETTE RIGHT (PORTS $00-$03)")
    for pixel = 0, 3 do
        local port = pixel
        palette_row(lines, "R", pixel, port, video.ports[port])
    end
    section(lines, "OTHER VIDEO PORTS")
    local ports = { 0x08, 0x09, 0x0A, 0x0B, 0x0C, 0x0D, 0x0E, 0x0F, 0x19 }
    for _, port in ipairs(ports) do
        line(lines, string.format("%02X %-14s %s", port,
            H.gorf.data.video_ports[port], raw8(video.ports[port])), H.colors.text)
    end
    section(lines, "PATTERN BOARD")
    for port = 0x78, 0x7E do
        line(lines, string.format("%02X %-14s %s", port,
            H.gorf.data.video_ports[port], raw8(video.ports[port])), H.colors.text)
    end
    section(lines, "RECENT HARDWARE")
    local recent = H.gorf.hardware(7)
    for index = 1, 7 do
        local event = recent[index]
        line(lines, event and string.format("%s %02X=%02X", event.kind, event.port, event.value) or "--",
            H.colors.dim)
    end
    return lines
end

function H.get_region()
    local config = H.gorf.config
    local region = {
        x0 = config.region.x0, y0 = config.region.y0,
        x1 = config.region.x1, y1 = config.region.y1
    }
    if not config.auto_place then return region end

    local ok = pcall(function()
        local target = H.gorf.runtime.machine.render.ui_target
        local view = target and target.current_view
        if not view or not view.items then return end
        local screen_bounds, screen_area = nil, 0
        for _, item in ipairs(view.items) do
            if safe_property(item, "element") == nil then
                local bounds = safe_property(item, "bounds")
                if bounds then
                    local area = math.max(0, bounds.x1 - bounds.x0) * math.max(0, bounds.y1 - bounds.y0)
                    if area > screen_area then screen_bounds, screen_area = bounds, area end
                end
            end
        end
        if not screen_bounds or screen_bounds.x1 >= 0.94 then return end
        region.x0 = math.max(region.x0, screen_bounds.x1 + 0.008)
        local lower_edge = region.y1
        for _, item in ipairs(view.items) do
            local bounds = safe_property(item, "bounds")
            if safe_property(item, "element") ~= nil and bounds
                and bounds.x0 >= screen_bounds.x1 - 0.01
                and bounds.y0 > region.y0 + 0.20 and bounds.y0 < lower_edge then
                lower_edge = bounds.y0 - 0.008
            end
        end
        if lower_edge > region.y0 + 0.20 then region.y1 = lower_edge end
    end)
    if not ok then return H.gorf.config.region end
    return region
end

function H.line_height()
    local value = 0.028
    local ui = safe_property(manager, "ui")
    local actual = ui and safe_property(ui, "line_height")
    if type(actual) == "number" and actual > 0 and actual < 0.1 then value = actual * 1.35 end
    return value
end

function H.character_limit(region, line_height)
    local target = H.gorf.runtime.machine.render.ui_target
    local width = target and safe_property(target, "width") or 1024
    local height = target and safe_property(target, "height") or 768
    local pixels = (region.x1 - region.x0 - 0.012) * width
    local glyph = math.max(6, line_height * height * 0.54)
    return math.max(12, math.floor(pixels / glyph))
end

function H.fit(text, maximum)
    text = tostring(text or "")
    if #text <= maximum then return text end
    if maximum <= 3 then return text:sub(1, maximum) end
    return text:sub(1, maximum - 3) .. "..."
end

function H.release_surface()
    if H.texture then pcall(function() H.texture:free() end) end
    if H.bitmap then pcall(function() H.bitmap:reset() end) end
    H.texture, H.bitmap = nil, nil
    H.surface_width, H.surface_height = nil, nil
end

function H.ensure_surface(width, height)
    if H.texture and H.surface_width == width and H.surface_height == height then return true end
    H.release_surface()
    if not emu.bitmap_argb32 then return false end
    local render = H.gorf.runtime.machine.render
    if not render or not render.texture_alloc then return false end
    local bitmap_ok, bitmap = pcall(emu.bitmap_argb32, width, height)
    if not bitmap_ok or not bitmap then return false end
    H.bitmap = bitmap
    local texture_ok, texture = pcall(function() return render:texture_alloc(H.bitmap) end)
    if not texture_ok or not texture then
        H.release_surface()
        return false
    end
    H.texture = texture
    H.surface_width, H.surface_height = width, height
    H.dirty = true
    return H.texture ~= nil
end

function H.draw_glyph(x, y, character, color, scale)
    local glyph = H.font[character:upper()] or H.font["?"]
    for row = 1, 7 do
        local bits = glyph[row]
        for column = 0, 4 do
            if (bits & (1 << (4 - column))) ~= 0 then
                H.bitmap:plot_box(x + column * scale, y + (row - 1) * scale, scale, scale, color)
            end
        end
    end
end

function H.draw_bitmap_text(x, y, text, color, scale, maximum)
    text = H.fit(tostring(text or ""), maximum)
    local advance = 6 * scale
    for index = 1, #text do
        H.draw_glyph(x + (index - 1) * advance, y, text:sub(index, index), color, scale)
    end
end

function H.render_bitmap(region, lines)
    local target = H.gorf.runtime.machine.render.ui_target
    local target_width = target and safe_property(target, "width") or 1024
    local target_height = target and safe_property(target, "height") or 768
    local width = math.max(32, math.floor((region.x1 - region.x0) * target_width + 0.5))
    local height = math.max(32, math.floor((region.y1 - region.y0) * target_height + 0.5))
    if not H.ensure_surface(width, height) then return false end

    H.bitmap:fill(H.colors.panel)
    local scale = H.gorf.config.font_scale or 1
    local pad_x, pad_y = 5, 5
    local advance = 6 * scale
    local line_height = 8 * scale + 1
    local maximum = math.max(8, math.floor((width - pad_x * 2) / advance))
    local y = pad_y
    for _, row in ipairs(lines) do
        if y + 7 * scale > height - pad_y then break end
        local text_maximum = row.swatch and math.max(8, maximum - 7) or maximum
        H.draw_bitmap_text(pad_x, y, row.text, row.color, scale, text_maximum)
        if row.swatch then
            local swatch_width = math.max(18, 5 * advance)
            local swatch_x = width - pad_x - swatch_width
            H.bitmap:plot_box(swatch_x - 1, y - 1, swatch_width + 2, 7 * scale + 2, H.colors.text)
            H.bitmap:plot_box(swatch_x, y, swatch_width, 7 * scale, row.swatch)
        end
        y = y + line_height
    end
    H.dirty = false
    return true
end

function H.draw_legacy(container, region, lines)
    local height = H.line_height()
    local pad_x, pad_y = 0.006, 0.004
    container:draw_box(region.x0, region.y0, region.x1, region.y1, H.colors.border, H.colors.panel)
    local maximum = H.character_limit(region, height)
    local y = region.y0 + pad_y
    for _, row in ipairs(lines) do
        if y + height > region.y1 - pad_y then break end
        local text_maximum = row.swatch and math.max(8, maximum - 7) or maximum
        container:draw_text(region.x0 + pad_x, y, H.fit(row.text, text_maximum), row.color, H.colors.transparent)
        if row.swatch then
            local swatch_x0 = region.x1 - 0.034
            container:draw_box(swatch_x0, y + height * 0.12, region.x1 - 0.007,
                y + height * 0.80, H.colors.text, row.swatch)
        end
        y = y + height
    end
end

function H.draw()
    if not H.gorf.running or not H.gorf.config.visible then return end
    local ok, message = pcall(function()
        local render = H.gorf.runtime.machine.render
        local container = render.ui_container or (render.ui_target and render.ui_target.ui_container)
        if not container then error("MAME UI render container is unavailable") end
        local region = H.get_region()
        local lines = H.last_lines
        if not H.gorf.config.hud_frozen or not lines then
            local snapshot = H.gorf.refresh()
            local builder = H["layout_" .. H.gorf.config.page] or H.layout_all
            lines = builder(snapshot)
            local warning = ""
            if #H.gorf.state.warnings > 0 then
                warning = "! " .. H.gorf.state.warnings[#H.gorf.state.warnings]
            end
            -- The warning slot is always present so a warning never moves the HUD body.
            line(lines, warning, H.colors.error)
            H.last_lines = lines

            local now = snapshot.time or 0
            local refresh_interval = 1 / math.max(1, H.gorf.config.hud_refresh_hz or 5)
            if H.dirty or not H.last_render_time or now < H.last_render_time
                or now - H.last_render_time >= refresh_interval then
                if H.render_bitmap(region, lines) then H.last_render_time = now end
            end
        end
        if H.texture then
            container:draw_quad(H.texture, region.x0, region.y0, region.x1, region.y1, 0xFFFFFFFF)
            container:draw_box(region.x0, region.y0, region.x1, region.y1,
                H.colors.border, H.colors.transparent)
        else
            H.draw_legacy(container, region, lines)
        end
    end)
    if ok then
        H.draw_count = (H.draw_count or 0) + 1
        H.last_error = nil
    else
        local error_text = tostring(message)
        H.last_error = error_text
        if H.reported_error ~= error_text then
            H.reported_error = error_text
            H.gorf.core.record_error("HUD", error_text)
        end
    end
end

function H.install_callback()
    -- UI primitives must be submitted after MAME finishes composing the frame.
    -- A machine-frame notifier can run before the UI container is rendered,
    -- which makes an otherwise successful HUD callback leave no visible panel.
    if emu.register_frame_done then
        emu.register_frame_done(function() H.draw() end, "gorf_monitor_hud")
        H.callback_style = "frame_done"
        return
    end

    local ok, subscription = pcall(function()
        return emu.add_machine_frame_notifier(function() H.draw() end)
    end)
    if not ok or not subscription then
        error("MAME provides no usable frame callback for the HUD")
    end
    H.subscription = subscription
    H.callback_style = "machine_frame"
end

function H.remove_callback()
    if H.subscription then pcall(function() H.subscription:unsubscribe() end) end
    if H.callback_style == "frame_done" and emu.register_frame_done then
        pcall(function() emu.register_frame_done(nil, "gorf_monitor_hud") end)
    end
    H.subscription = nil
    H.callback_style = nil
end

function H.attach(gorf)
    H.gorf = gorf
    gorf.hud = H
    gorf.page = function(name)
        name = tostring(name or "all"):lower()
        if not H["layout_" .. name] then error("unknown HUD page: " .. name) end
        gorf.config.page = name
        H.dirty = true
        return name
    end
    gorf.next_page = function()
        local current = 1
        for index, name in ipairs(H.page_order) do
            if name == gorf.config.page then current = index break end
        end
        return gorf.page(H.page_order[(current % #H.page_order) + 1])
    end
    for _, page_name in ipairs(H.page_order) do
        local selected_page = page_name
        gorf["show_" .. selected_page] = function()
            return gorf.page(selected_page)
        end
    end
    gorf.visible = function(value)
        if value ~= nil then gorf.config.visible = not not value end
        return gorf.config.visible
    end
    gorf.freeze = function(value)
        if value ~= nil then
            gorf.config.hud_frozen = not not value
            if not gorf.config.hud_frozen then H.dirty = true end
        end
        return gorf.config.hud_frozen
    end
    gorf.set_region = function(x0, y0, x1, y1)
        assert(type(x0) == "number" and type(y0) == "number"
            and type(x1) == "number" and type(y1) == "number", "region requires four numbers")
        assert(x0 >= 0 and y0 >= 0 and x1 <= 1 and y1 <= 1 and x1 > x0 and y1 > y0,
            "region must be a normalized rectangle inside 0..1")
        gorf.config.region = { x0 = x0, y0 = y0, x1 = x1, y1 = y1 }
        gorf.config.auto_place = false
        H.dirty = true
        return string.format("%.3f,%.3f - %.3f,%.3f", x0, y0, x1, y1)
    end
    gorf.auto_place = function(value)
        if value ~= nil then
            gorf.config.auto_place = not not value
            H.dirty = true
        end
        return gorf.config.auto_place
    end
    gorf.font_scale = function(value)
        if value ~= nil then
            assert(type(value) == "number" and value >= 1 and value <= 4 and value % 1 == 0,
                "font scale must be an integer from 1 to 4")
            gorf.config.font_scale = value
            H.dirty = true
        end
        return gorf.config.font_scale
    end
    gorf.refresh_rate = function(value)
        if value ~= nil then
            assert(type(value) == "number" and value >= 1 and value <= 30,
                "refresh rate must be from 1 to 30 Hz")
            gorf.config.hud_refresh_hz = value
            H.dirty = true
        end
        return gorf.config.hud_refresh_hz
    end
    gorf.stop_hud = function()
        H.remove_callback()
        H.release_surface()
    end
    H.dirty = true
    H.draw_count = 0
    H.last_error = nil
    H.reported_error = nil
    H.last_lines = nil
    H.install_callback()
    return gorf
end

return H
