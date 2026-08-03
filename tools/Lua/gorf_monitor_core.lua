-- gorf_monitor_core.lua

local C = {}
C.module_name = "core"
C.api_version = 1
C.revision = "2.0.2-20260803"

-- Add this to the very top of your file alongside your local initializations
if not G_logged_discoveries then
    G_logged_discoveries = {}
end


-- At $0060 DSPATCH has fetched the target into HL and advanced BC past the
-- two-byte threaded entry.  Filtering on PC=$0060 excludes unrelated reads of
-- dispatcher ROM bytes from the trace.
local TERSE_DISPATCH_EXECUTION = 0x0060

-- At $0F37 the native music interpreter has completed LD A,(HL).  HL still
-- identifies the opcode byte and IY identifies one of the two music engines.
local MUSIC_OPCODE_EXECUTION = 0x0F37

-- These are behavioral descriptions of otherwise unnamed native targets. They
-- are kept separate from exact source symbols and displayed as decoded detail.
local TARGET_DESCRIPTIONS = {
    [0x0F98] = "SERVICES BOTH MUSIC ENGINES"
}

function C.hex(value, width)
    return string.format("%0" .. tostring(width or 4) .. "X", (value or 0) & 0xFFFF)
end

function C.machine()
    local ok, value = pcall(function() return manager.machine end)
    if ok and value then return value end
    ok, value = pcall(function() return manager:machine() end)
    if ok then return value end
    return nil
end

function C.print_info(message)
    if emu and emu.print_info then
        emu.print_info(message)
    else
        print(message)
    end
end

function C.find_cpu(machine)
    local cpu = machine.devices[":maincpu"] or machine.devices[":cpu"]
    if cpu then return cpu end
    for _, device in pairs(machine.devices) do
        if device.spaces and device.state then return device end
    end
    return nil
end

function C.find_space(cpu, preferred, pattern)
    if cpu.spaces[preferred] then return cpu.spaces[preferred] end
    for name, space in pairs(cpu.spaces) do
        local display = tostring(name) .. " " .. tostring(space.name or "")
        if display:lower():find(pattern, 1, true) then return space end
    end
    return nil
end

function C.find_state(cpu, names)
    for _, name in ipairs(names) do
        local entry = cpu.state[name]
        if entry then return entry end
    end
    return nil
end

function C.register_value(name)
    local entry = C.g.runtime.registers[name]
    if not entry then return 0 end
    return entry.value & 0xFFFF
end

function C.emulated_time()
    local time = C.g.runtime.machine.time
    if time and time.as_double then
        local ok, value = pcall(function() return time:as_double() end)
        if ok then return value end
    end
    return os.clock()
end

function C.ring(capacity)
    return { capacity = capacity, head = 0, count = 0, items = {} }
end

function C.ring_push(ring, value)
    ring.head = (ring.head % ring.capacity) + 1
    ring.items[ring.head] = value
    if ring.count < ring.capacity then ring.count = ring.count + 1 end
end

function C.ring_recent(ring, maximum)
    local result = {}
    local count = math.min(maximum or ring.count, ring.count)
    for index = 0, count - 1 do
        local slot = ((ring.head - index - 1) % ring.capacity) + 1
        result[#result + 1] = ring.items[slot]
    end
    return result
end

function C.u8(address)
    return C.g.runtime.read_u8(address & 0xFFFF) & 0xFF
end

function C.u8_direct(address)
    return C.g.runtime.read_direct_u8(address & 0xFFFF) & 0xFF
end

function C.u16(address)
    local low = C.u8(address)
    local high = C.u8(address + 1)
    return low | (high << 8)
end

function C.bcd_score(address)
    return string.format("%02X%02X%02X", C.u8(address + 2), C.u8(address + 1), C.u8(address))
end

function C.label(address)
    address = address & 0xFFFF
    return C.g.data.entries[address] or C.g.data.symbols[address]
        or C.g.runtime.lst_symbols[address]
        or ("$" .. C.hex(address))
end

function C.target_decode(address, high_level)
    local builtin = C.g.data.entries[address] or C.g.data.symbols[address]
    local imported = not builtin and C.g.runtime.lst_symbols[address] or nil
    local exact = builtin or imported
    local nearest = nil
    
    if not exact then
        local candidate = C.pc_label(address)
        if candidate ~= "$" .. C.hex(address) then
            nearest = candidate
        end
    end

    local stream_preview = nil
    if address and address > 0 and address < 0xFFFF then
        local b0 = C.u8_direct(address)
        local b1 = C.u8_direct(address + 1)
        local b2 = C.u8_direct(address + 2)
        
        -- Check if it's a TERSE Jump block (RST 08)
        if b0 == 0xCF then
            -- Reconstruct the Little-Endian 16-bit pointer value (e.g. $2C + $B300 = $B32C)
            local target_ptr = b1 + (b2 * 256)
            
            -- Look up if this resolved destination has a mapped name
            local ptr_name = C.g.data.entries[target_ptr] or C.g.data.symbols[target_ptr]
            
            if ptr_name then
                stream_preview = string.format("[RST08 -> %s]", ptr_name)
            else
                stream_preview = string.format("[RST08 -> $%04X]", target_ptr)
            end
        else
            -- Fallback for regular primitive assembly blocks
            local n0 = C.g.data.entries[b0] or string.format("$%02X", b0)
            local n1 = C.g.data.entries[b1] or string.format("$%02X", b1)
            local n2 = C.g.data.entries[b2] or string.format("$%02X", b2)
            stream_preview = string.format("[%s %s %s]", n0, n1, n2)
        end
    end

    return {
        exact_name = exact,
        exact_source = builtin and "BUILT-IN" or (imported and "LST" or nil),
        display_name = exact or (high_level and "UNKNOWN TERSE WORD" or "UNKNOWN NATIVE TARGET"),
        class = high_level and "TERSE WORD" or "NATIVE PRIMITIVE",
        description = TARGET_DESCRIPTIONS and TARGET_DESCRIPTIONS[address] or nil,
        nearest_symbol = nearest,
        terse_stream_preview = stream_preview 
    }
end

function C.pc_label(address)
    local order = C.g.runtime.symbol_order
    local low, high = 1, #order
    local best = nil
    while low <= high do
        local middle = (low + high) // 2
        if order[middle] <= address then
            best = order[middle]
            low = middle + 1
        else
            high = middle - 1
        end
    end
    if not best or address - best > 0x0100 then return "$" .. C.hex(address) end
    local name = C.g.data.symbols[best] or C.g.runtime.lst_symbols[best]
    if address == best then return name end
    return name .. "+$" .. C.hex(address - best, 2)
end

function C.phrase_for_pointer(pointer)
    for _, phrase in ipairs(C.g.data.speech_phrases) do
        local length = C.u8_direct(phrase.address)
        if pointer == phrase.address or (pointer > phrase.address and pointer <= phrase.address + length) then
            return phrase.name, phrase.address
        end
    end
    return nil, nil
end

function C.stack_words(pointer, base, maximum)
    local values = {}
    if pointer > base or pointer < 0xD000 or ((base - pointer) & 1) ~= 0 then return values end
    local depth = (base - pointer) // 2
    for index = 0, math.min(depth, maximum or 4) - 1 do
        values[#values + 1] = C.u16(pointer + index * 2)
    end
    return values
end

function C.inline_detail(ip, target)
    local kind = C.g.data.inline_words[target]
    if not kind then return nil end
    if kind == "byte" then
        return "#$" .. C.hex(C.u8_direct(ip + 2), 2)
    elseif kind == "word" or kind == "address" then
        local value = C.u8_direct(ip + 2) | (C.u8_direct(ip + 3) << 8)
        local symbol = C.g.data.symbols[value] or C.g.data.entries[value]
        return symbol and ("$" .. C.hex(value) .. " " .. symbol) or ("#$" .. C.hex(value))
    elseif kind == "branch" then
        local value = C.u8_direct(ip + 2) | (C.u8_direct(ip + 3) << 8)
        return "->$" .. C.hex(value) .. " " .. C.label(value)
    elseif kind == "quad" then
        local first = C.u8_direct(ip + 2) | (C.u8_direct(ip + 3) << 8)
        local second = C.u8_direct(ip + 4) | (C.u8_direct(ip + 5) << 8)
        return "#$" .. C.hex(first) .. " #$" .. C.hex(second)
    elseif kind == "string" then
        return "len=" .. tostring(C.u8_direct(ip + 2))
    end
    return nil
end

function C.reset_trace()
    local state = C.g.state
    state.total_words = 0
    state.dispatch_since_frame = 0
    state.frame_words = 0
    state.word_rate = 0
    state.word_counts = {}
    state.unknown_counts = {}
    state.call_stack = {}
    state.trace = C.ring(C.g.config.trace_capacity)
    state.last_dispatch = nil
    state.rate_time = C.emulated_time()
    state.rate_words = 0
end

function C.record_error(area, message)
    local key = area .. ":" .. tostring(message)
    if C.g.state.reported_errors[key] then return end
    C.g.state.reported_errors[key] = true
    C.g.state.warnings[#C.g.state.warnings + 1] = area .. ": " .. tostring(message)
    C.print_info("[GORF MONITOR] " .. area .. ": " .. tostring(message))
end

function C.on_dispatch()
    if not C.g.running or not C.g.config.exact_trace then return end
    local ok, message = pcall(function()
        local state = C.g.state
        local pc = C.register_value("PC")
        if pc ~= TERSE_DISPATCH_EXECUTION then return end
        local ip = (C.register_value("BC") - 2) & 0xFFFF
        local target = C.register_value("HL")
        local entry_at_ip = nil
        if ip > 0 and C.u8_direct(ip - 1) == 0xCF then entry_at_ip = ip - 1 end

        if entry_at_ip then
            local top = state.call_stack[#state.call_stack]
            if not top or top.address ~= entry_at_ip then
                if entry_at_ip == 0xBFB0 then state.call_stack = {} end
                local name = C.g.data.entries[entry_at_ip] or C.g.data.symbols[entry_at_ip]
                if not name then
                    name = "UNKNOWN TERSE $" .. C.hex(entry_at_ip)
                end
                state.call_stack[#state.call_stack + 1] = {
                    address = entry_at_ip, name = name, caller_ip = ip
                }
            end
        end

        local high_level = C.g.data.entries[target] ~= nil or C.u8_direct(target) == 0xCF
        local decoded = C.target_decode(target, high_level)
        local name = decoded.exact_name or decoded.display_name

        local stack_top = C.stack_words(C.register_value("SP"), C.g.data.address.PSP, 5)
        local current = state.call_stack[#state.call_stack]
        local event = {
            sequence = state.total_words + 1,
            time = C.emulated_time(),
            ip = ip,
            target = target,
            name = name,
            decoded_name = decoded.exact_name,
            decoded_source = decoded.exact_source,
            target_class = decoded.class,
            decoded_description = decoded.description,
            nearest_symbol = decoded.nearest_symbol,
            terse_stream_preview = decoded.terse_stream_preview,
            detail = C.inline_detail(ip, target),
            reconstructed_context = current and current.name or nil,
            reconstructed_context_address = current and current.address or nil,
            reconstructed_stream_offset = current and ((ip - current.address) & 0xFFFF) or nil,
            reconstructed_call_depth = #state.call_stack,
            sp = C.register_value("SP"),
            ix = C.register_value("IX"),
            stack = stack_top,
            kind = high_level and "call" or (target == 0x0061 and "return" or "word")
        }

        state.total_words = event.sequence
        state.dispatch_since_frame = state.dispatch_since_frame + 1
        state.word_counts[target] = (state.word_counts[target] or 0) + 1
        if not decoded.exact_name then
            state.unknown_counts[target] = (state.unknown_counts[target] or 0) + 1
        end
        state.last_dispatch = event
        C.ring_push(state.trace, event)

        -- print to the terminal if the target is completely unmapped
        if not decoded.exact_name and event.terse_stream_preview then

            -- Check if we have already printed this specific target address before
            if not G_logged_discoveries[event.target] then
                -- Mark it as logged
                G_logged_discoveries[event.target] = true            
                -- Streams out directly to terminal console window
                print(string.format("[DISCOVERY] IP: $%04X -> Target: $%04X | %s (Context: %s)", 
                    event.ip, event.target, event.terse_stream_preview, event.reconstructed_context or "NONE"))
                    
                -- Sends it to MAME's internal error/debug log utility
                -- manager.machine:logerror(string.format("GORF_TRACK: $%04X -> $%04X\n", event.ip, event.target))
            end
        end        

        if high_level then
            state.call_stack[#state.call_stack + 1] = {
                address = target, name = name, caller_ip = ip + 2
            }
        elseif target == 0x0061 and #state.call_stack > 0 then
            table.remove(state.call_stack)
        end
    end)
    if not ok then C.record_error("dispatcher tap", message) end
end

function C.hardware_event(kind, port, value, name)
    local pc = C.register_value("PC")
    local event = {
        time = C.emulated_time(), kind = kind, port = port, value = value,
        name = name, pc = pc, origin = C.pc_label(pc)
    }
    C.ring_push(C.g.state.hardware_events, event)
    return event
end

function C.on_io_write(offset, data)
    if not C.g.running then return data end
    local ok, message = pcall(function()
        local port = offset & 0xFF
        local value = data & 0xFF
        if port >= 0x10 and port <= 0x17 then
            local index = port - 0x10 + 1
            C.g.state.sound[1].registers[index] = value
            local event = C.hardware_event("sound1", port, value, C.g.data.sound_registers[index])
            C.g.state.sound[1].last = event
            C.ring_push(C.g.state.audio_events, event)
        elseif port >= 0x50 and port <= 0x57 then
            local index = port - 0x50 + 1
            C.g.state.sound[2].registers[index] = value
            local event = C.hardware_event("sound2", port, value, C.g.data.sound_registers[index])
            C.g.state.sound[2].last = event
            C.ring_push(C.g.state.audio_events, event)
        elseif C.g.data.video_ports[port] then
            C.g.state.video.ports[port] = value
            C.g.state.video.last = C.hardware_event("video", port, value, C.g.data.video_ports[port])
        end
    end)
    if not ok then C.record_error("I/O write tap", message) end
    return data
end

function C.on_io_read(offset, data)
    if not C.g.running then return data end
    local port = offset & 0xFF
    if port ~= 0x17 then return data end
    local pc = C.register_value("PC")
    if pc ~= 0x111D and pc ~= 0x1150 then return data end
    local ok, message = pcall(function()
        local raw = (C.register_value("BC") >> 8) & 0xFF
        local code = raw & 0x3F
        local name = C.g.data.phonemes[code] or ("$" .. C.hex(code, 2))
        local pointer = pc == 0x1150 and ((C.register_value("HL") - 1) & 0xFFFF) or C.u16(C.g.data.address.TALK_HERE)
        local phrase, phrase_address = nil, nil
        if pc == 0x1150 then
            phrase, phrase_address = C.phrase_for_pointer(pointer)
        end
        local suffix = ""
        if (raw & 0x80) ~= 0 then suffix = suffix .. " HI" end
        if (raw & 0x40) ~= 0 then suffix = suffix .. " UP" end
        local speech = C.g.state.speech
        local event = {
            time = C.emulated_time(), raw = raw, code = code, name = name,
            display = name .. suffix, primitive = phrase,
            primitive_address = phrase_address, pc = pc
        }
        speech.last_phoneme = event
        C.ring_push(speech.phonemes, event)
        if code == 0x3F then
            if speech.speaking then
                speech.last_spoken = speech.speaking
                C.ring_push(speech.utterances, {
                    time = event.time, phrase = speech.speaking
                })
            end
            speech.speaking = nil
            speech.speaking_primitive = nil
            speech.speaking_address = nil
            speech.speaking_parts = {}
            speech.last_pointer = nil
        elseif phrase then
            local starts_primitive = pointer == phrase_address + 1
            local changed_primitive = speech.speaking_address ~= phrase_address
            local repeated_primitive = starts_primitive and speech.last_pointer
                and pointer <= speech.last_pointer
            if not speech.speaking or changed_primitive or repeated_primitive then
                speech.speaking_parts[#speech.speaking_parts + 1] = phrase
                speech.speaking = table.concat(speech.speaking_parts, " ")
            end
            speech.speaking_primitive = phrase
            speech.speaking_address = phrase_address
            speech.last_pointer = pointer
        end
    end)
    if not ok then C.record_error("Votrax read tap", message) end
    return data
end

function C.on_music_opcode()
    if not C.g.running then return end
    local ok, message = pcall(function()
        if C.register_value("PC") ~= MUSIC_OPCODE_EXECUTION then return end
        local base = C.register_value("IY")
        local engine = base == C.g.data.address.MUSIC_1 and 1
            or (base == C.g.data.address.MUSIC_2 and 2 or nil)
        if not engine then return end

        local pointer = C.register_value("HL")
        local opcode = C.u8_direct(pointer)
        local event = {
            time = C.emulated_time(),
            kind = "music" .. engine,
            engine = engine,
            base = base,
            pc = pointer,
            opcode = opcode,
            opcode_name = C.g.data.music_opcodes[opcode] or ("OP_$" .. C.hex(opcode, 2))
        }
        C.g.state.music[engine].last_executed = event
        C.ring_push(C.g.state.audio_events, event)
    end)
    if not ok then C.record_error("music execution tap", message) end
end

function C.music_snapshot(base, engine)
    local next_pc = C.u16(base)
    local next_opcode = next_pc ~= 0 and C.u8_direct(next_pc) or nil
    return {
        base = base,
        next_pc = next_pc,
        next_opcode = next_opcode,
        next_opcode_name = next_opcode and
            (C.g.data.music_opcodes[next_opcode] or ("OP_$" .. C.hex(next_opcode, 2))) or nil,
        last_executed = C.g.state.music[engine].last_executed,
        start_pc = C.u16(base + 2),
        soundbox = C.u8(base + 4),
        ramble = C.u8(base + 0x0A),
        limit = C.u8(base + 0x10),
        note_timer = C.u8(base + 0x2E),
        mst = C.u8(base + 0x2F)
    }
end

function C.refresh()
    local state = C.g.state
    local now = C.emulated_time()
    local delta = now - state.rate_time
    if delta < 0 then
        state.rate_time, state.rate_words = now, state.total_words
    elseif delta >= 0.25 then
        state.word_rate = (state.total_words - state.rate_words) / delta
        state.rate_time, state.rate_words = now, state.total_words
    end

    state.frame_words = state.dispatch_since_frame
    state.dispatch_since_frame = 0
    local regs = {
        pc = C.register_value("PC"), bc = C.register_value("BC"),
        sp = C.register_value("SP"), ix = C.register_value("IX"),
        iy = C.register_value("IY"), hl = C.register_value("HL")
    }
    local game = {}
    for name, address in pairs(C.g.data.game_fields) do game[name] = C.u8(address) end
    game.P1_SCORE = C.bcd_score(C.g.data.game_fields.P1SCR)
    game.P2_SCORE = C.bcd_score(C.g.data.game_fields.P2SCR)
    game.MISSION_NAME = C.g.data.missions[game.MISSION]
    game.RANK_NAME = C.g.data.ranks[game.SKILLFACTOR]
    game.PLAYER_NUMBER = game.PLAYERUP <= 1 and game.PLAYERUP + 1 or nil
    game.PLAYER_COUNT = game.NPLAYERS == 0 and 1
        or (game.NPLAYERS == 1 and 2 or nil)

    local talk_here = C.u16(C.g.data.address.TALK_HERE)
    local talk_in = C.u16(C.g.data.address.TALK_IN)
    local talk_out = C.u16(C.g.data.address.TALK_OUT)
    local queued_address, queued_name = nil, nil
    if talk_in ~= talk_out
        and talk_out >= C.g.data.address.TALK_TOP
        and talk_out <= C.g.data.address.TALK_BOTTOM then
        queued_address = C.u16(talk_out)
        queued_name = C.phrase_for_pointer(queued_address)
    end
    local speech = {
        on_hold = C.u8(C.g.data.address.ON_HOLD),
        remaining = C.u8(C.g.data.address.PHONE_COUNT),
        talk_here = talk_here,
        talk_in = talk_in,
        talk_out = talk_out,
        speaking = state.speech.speaking,
        speaking_primitive = state.speech.speaking_primitive,
        speaking_address = state.speech.speaking_address,
        last_spoken = state.speech.last_spoken,
        queued_address = queued_address,
        queued_name = queued_name,
        last_phoneme = state.speech.last_phoneme
    }

    state.snapshot = {
        time = now, registers = regs, game = game, speech = speech,
        music = {
            C.music_snapshot(C.g.data.address.MUSIC_1, 1),
            C.music_snapshot(C.g.data.address.MUSIC_2, 2)
        },
        sound = state.sound, video = state.video,
        terse = {
            total_words = state.total_words, frame_words = state.frame_words,
            word_rate = state.word_rate, last = state.last_dispatch,
            reconstructed_call_stack = state.call_stack,
            reconstructed_parameter_depth = regs.sp <= C.g.data.address.PSP
                and (C.g.data.address.PSP - regs.sp) // 2 or 0,
            reconstructed_return_cells = regs.ix <= C.g.data.address.RSP
                and (C.g.data.address.RSP - regs.ix) // 2 or 0
        }
    }
    return state.snapshot
end

function C.verify_rom()
    local failures = {}
    for _, item in ipairs(C.g.data.rom_signature) do
        local actual = C.u8_direct(item.address)
        if actual ~= item.value then
            failures[#failures + 1] = "$" .. C.hex(item.address) .. "=" .. C.hex(actual, 2)
        end
    end
    if #failures > 0 then
        C.g.state.warnings[#C.g.state.warnings + 1] = "ROM signature differs: " .. table.concat(failures, ", ")
    end
end

function C.install_taps()
    local runtime = C.g.runtime
    runtime.taps.dispatch = runtime.program:install_read_tap(
        TERSE_DISPATCH_EXECUTION, TERSE_DISPATCH_EXECUTION,
        "gorf_monitor_terse_dispatch",
        function(offset, data, mask)
            C.on_dispatch()
            return data
        end
    )
    runtime.taps.music_execution = runtime.program:install_read_tap(
        MUSIC_OPCODE_EXECUTION, MUSIC_OPCODE_EXECUTION,
        "gorf_monitor_music_opcode_execution",
        function(offset, data, mask)
            C.on_music_opcode()
            return data
        end
    )

    if runtime.io then
        local end_address = runtime.io.address_mask or 0xFFFF
        runtime.taps.io_write = runtime.io:install_write_tap(
            0, end_address, "gorf_monitor_io_write",
            function(offset, data, mask) return C.on_io_write(offset, data) end
        )
        runtime.taps.io_read = runtime.io:install_read_tap(
            0, end_address, "gorf_monitor_io_read",
            function(offset, data, mask) return C.on_io_read(offset, data) end
        )
    else
        C.g.state.warnings[#C.g.state.warnings + 1] = "CPU I/O space was not found; hardware event tracking is disabled."
    end

    if runtime.program.add_change_notifier then
        runtime.subscriptions[#runtime.subscriptions + 1] = runtime.program:add_change_notifier(function(kind)
            if kind == "r" or kind == "rw" then
                if runtime.taps.dispatch then runtime.taps.dispatch:reinstall() end
                if runtime.taps.music_execution then runtime.taps.music_execution:reinstall() end
            end
        end)
    end
    if runtime.io and runtime.io.add_change_notifier then
        runtime.subscriptions[#runtime.subscriptions + 1] = runtime.io:add_change_notifier(function(kind)
            if (kind == "r" or kind == "rw") and runtime.taps.io_read then runtime.taps.io_read:reinstall() end
            if (kind == "w" or kind == "rw") and runtime.taps.io_write then runtime.taps.io_write:reinstall() end
        end)
    end
end

function C.remove_runtime_hooks()
    if not C.g or not C.g.runtime then return end
    for _, tap in pairs(C.g.runtime.taps or {}) do
        pcall(function() tap:remove() end)
    end
    for _, subscription in ipairs(C.g.runtime.subscriptions or {}) do
        pcall(function() subscription:unsubscribe() end)
    end
    C.g.runtime.taps = {}
    C.g.runtime.subscriptions = {}
end

function C.sorted_counts(source)
    local result = {}
    for address, count in pairs(source) do result[#result + 1] = { address = address, count = count } end
    table.sort(result, function(left, right)
        if left.count == right.count then return left.address < right.address end
        return left.count > right.count
    end)
    return result
end

function C.csv_field(value)
    local text = tostring(value or "")
    if text:find('[,\n\r"]') then return '"' .. text:gsub('"', '""') .. '"' end
    return text
end

function C.rebuild_symbol_order()
    local seen = {}
    local order = {}
    for address in pairs(C.g.data.symbols) do
        if address <= 0xBFFF then seen[address] = true end
    end
    for address in pairs(C.g.runtime.lst_symbols) do
        if address <= 0xBFFF then seen[address] = true end
    end
    for address in pairs(seen) do order[#order + 1] = address end
    table.sort(order)
    C.g.runtime.symbol_order = order
end

function C.refresh_symbol_decodes()
    for _, event in pairs(C.g.state.trace.items) do
        local high_level = event.target_class == "TERSE WORD" or C.u8_direct(event.target) == 0xCF
        local decoded = C.target_decode(event.target, high_level)
        event.name = decoded.exact_name or decoded.display_name
        event.decoded_name = decoded.exact_name
        event.decoded_source = decoded.exact_source
        event.target_class = decoded.class
        event.decoded_description = decoded.description
        event.nearest_symbol = decoded.nearest_symbol
    end
    for _, frame in ipairs(C.g.state.call_stack) do
        local exact = C.g.data.entries[frame.address] or C.g.data.symbols[frame.address]
            or C.g.runtime.lst_symbols[frame.address]
        if exact then frame.name = exact end
    end
    local unknown = {}
    for address, count in pairs(C.g.state.word_counts) do
        if not (C.g.data.entries[address] or C.g.data.symbols[address]
            or C.g.runtime.lst_symbols[address]) then
            unknown[address] = count
        end
    end
    C.g.state.unknown_counts = unknown
    if C.g.hud then C.g.hud.dirty = true end
end

function C.load_lst(path)
    assert(type(path) == "string" and path ~= "", "LST path is required")
    local file, message = io.open(path, "r")
    assert(file, message)
    local imported, duplicates, conflicts = 0, 0, 0
    for source_line in file:lines() do
        local address_text, label = source_line:match(
            "\t([%x][%x][%x][%x])%s+[%x]+%s+([%a_.$?@][%w_.$?@]*):")
        if not address_text then
            address_text, label = source_line:match(
                "\t([%x][%x][%x][%x])%s+([%a_.$?@][%w_.$?@]*)%s+EQU")
        end
        if address_text and label then
            local address = tonumber(address_text, 16)
            local builtin = C.g.data.entries[address] or C.g.data.symbols[address]
            local existing = C.g.runtime.lst_symbols[address]
            if builtin then
                if builtin == label then duplicates = duplicates + 1 else conflicts = conflicts + 1 end
            elseif existing then
                if existing == label then duplicates = duplicates + 1 else conflicts = conflicts + 1 end
            else
                C.g.runtime.lst_symbols[address] = label
                imported = imported + 1
            end
        end
    end
    file:close()
    C.rebuild_symbol_order()
    C.refresh_symbol_decodes()
    C.print_info(string.format(
        "[GORF MONITOR] LST symbols: %d imported, %d already known, %d conflicts kept existing",
        imported, duplicates, conflicts))
    return { imported = imported, duplicates = duplicates, conflicts = conflicts }
end

function C.save_trace(path, count)
    assert(type(path) == "string" and path ~= "", "trace path is required")
    local file, message = io.open(path, "w")
    assert(file, message)
    file:write("sequence,time,stream_address,target,decoded_name,decoded_source,target_class,decoded_description,nearest_symbol,reconstructed_context,reconstructed_context_address,reconstructed_stream_offset,detail,sp,ix,reconstructed_call_depth,stack\n")
    local rows = C.ring_recent(C.g.state.trace, count or C.g.state.trace.count)
    for index = #rows, 1, -1 do
        local event = rows[index]
        local stack = {}
        for _, value in ipairs(event.stack) do stack[#stack + 1] = C.hex(value) end
        file:write(table.concat({
            event.sequence,
            string.format("%.6f", event.time),
            C.hex(event.ip),
            C.hex(event.target),
            C.csv_field(event.decoded_name),
            C.csv_field(event.decoded_source),
            C.csv_field(event.target_class),
            C.csv_field(event.decoded_description),
            C.csv_field(event.nearest_symbol),
            C.csv_field(event.reconstructed_context),
            event.reconstructed_context_address and C.hex(event.reconstructed_context_address) or "",
            event.reconstructed_stream_offset and C.hex(event.reconstructed_stream_offset) or "",
            C.csv_field(event.detail),
            C.hex(event.sp),
            C.hex(event.ix),
            event.reconstructed_call_depth,
            C.csv_field(table.concat(stack, " "))
        }, ","), "\n")
    end
    file:close()
    C.print_info(string.format("[GORF MONITOR] wrote %d trace rows to %s", #rows, path))
    return #rows
end

function C.save_discovery(path)
    assert(type(path) == "string" and path ~= "", "discovery path is required")
    local file, message = io.open(path, "w")
    assert(file, message)
    file:write("; Runtime targets absent from the current Gorf symbol map.\n")
    file:write("; Labels follow the TERSE naming rules; verify semantics before merging.\n\n")
    local rows = {}
    for address, count in pairs(C.g.state.unknown_counts) do
        rows[#rows + 1] = { address = address, count = count }
    end
    table.sort(rows, function(left, right) return left.address < right.address end)
    for _, row in ipairs(rows) do
        local high_level = C.u8_direct(row.address) == 0xCF
        local name = high_level and ("_W_" .. C.hex(row.address))
            or ("code_" .. C.hex(row.address):lower())
        file:write(string.format("%-16s EQU $%04X ; %s, observed %d times\n",
            name, row.address, high_level and "TERSE high-level word" or "low-level/native target", row.count))
    end
    file:close()
    C.print_info(string.format("[GORF MONITOR] wrote %d discoveries to %s", #rows, path))
    return #rows
end

function C.attach(gorf)
    C.g = gorf
    local machine = C.machine()
    if not machine then error("MAME running machine is not available") end
    local cpu = C.find_cpu(machine)
    if not cpu then error("main CPU device was not found") end
    local program = C.find_space(cpu, "program", "program")
    if not program then error("main CPU program space was not found") end
    local io = C.find_space(cpu, "io", "io") or C.find_space(cpu, "i/o", "i/o")

    gorf.runtime = {
        machine = machine, cpu = cpu, program = program, io = io,
        taps = {}, subscriptions = {}, registers = {}, symbol_order = {}, lst_symbols = {}
    }
    gorf.runtime.registers = {
        PC = C.find_state(cpu, { "CURPC", "PC", "pc" }),
        BC = C.find_state(cpu, { "BC", "bc" }),
        SP = C.find_state(cpu, { "SP", "sp" }),
        IX = C.find_state(cpu, { "IX", "ix" }),
        IY = C.find_state(cpu, { "IY", "iy" }),
        HL = C.find_state(cpu, { "HL", "hl" })
    }
    for name, entry in pairs(gorf.runtime.registers) do
        if not entry then error("required Z80 register is unavailable: " .. name) end
    end

    -- Keep module attachment on the proven direct-read path.  Some MAME builds
    -- expose address-space methods through userdata properties that can raise
    -- while they are queried during an autoboot script.  Resolve both methods
    -- defensively, then attempt mapped reads only when RAM is sampled.
    local function address_space_method(name)
        local ok, method = pcall(function() return program[name] end)
        return ok and type(method) == "function" and method or nil
    end

    local direct_read_u8 = address_space_method("read_direct_u8")
    local mapped_read_u8 = address_space_method("read_u8")
    if not direct_read_u8 and not mapped_read_u8 then
        error("program space provides no byte-read method")
    end

    gorf.runtime.read_direct_u8 = function(address)
        if direct_read_u8 then return direct_read_u8(program, address) end
        return mapped_read_u8(program, address)
    end
    gorf.runtime.read_u8 = function(address)
        if mapped_read_u8 then
            local ok, value = pcall(mapped_read_u8, program, address)
            if ok and type(value) == "number" then return value end
        end
        return gorf.runtime.read_direct_u8(address)
    end
    C.rebuild_symbol_order()

    gorf.state = {
        warnings = {}, reported_errors = {}, total_words = 0, dispatch_since_frame = 0,
        frame_words = 0, word_rate = 0, word_counts = {}, unknown_counts = {},
        call_stack = {}, trace = C.ring(gorf.config.trace_capacity),
        hardware_events = C.ring(gorf.config.hardware_capacity), last_dispatch = nil,
        audio_events = C.ring(gorf.config.hardware_capacity),
        sound = {
            { registers = {}, last = nil },
            { registers = {}, last = nil }
        },
        video = { ports = {}, last = nil },
        music = {
            { last_executed = nil },
            { last_executed = nil }
        },
        speech = {
            phonemes = C.ring(gorf.config.phoneme_capacity),
            utterances = C.ring(gorf.config.utterance_capacity),
            last_phoneme = nil, speaking = nil, speaking_primitive = nil,
            speaking_address = nil,
            speaking_parts = {}, last_spoken = nil, last_pointer = nil
        },
        snapshot = nil, rate_time = 0, rate_words = 0
    }
    gorf.state.rate_time = C.emulated_time()
    gorf.running = true
    gorf.core = C
    C.verify_rom()
    C.install_taps()

    gorf.refresh = function() return C.refresh() end
    gorf.get_snapshot = function() return gorf.state.snapshot or C.refresh() end
    gorf.reset_trace = function() C.reset_trace() end
    gorf.recent = function(count) return C.ring_recent(gorf.state.trace, count or 20) end
    gorf.hardware = function(count) return C.ring_recent(gorf.state.hardware_events, count or 20) end
    gorf.dump = function(count)
        for _, event in ipairs(C.ring_recent(gorf.state.trace, count or 30)) do
            C.print_info(string.format(
                "#%d IP=$%04X -> $%04X %-16s ctx=%s%s",
                event.sequence, event.ip, event.target, event.name,
                event.reconstructed_context or "--",
                event.detail and (" " .. event.detail) or ""))
        end
    end
    gorf.hot = function(count)
        local rows = C.sorted_counts(gorf.state.word_counts)
        for index = 1, math.min(count or 20, #rows) do
            local row = rows[index]
            C.print_info(string.format("%8d  $%04X  %s", row.count, row.address, C.label(row.address)))
        end
    end
    gorf.unknown = function(count)
        local rows = C.sorted_counts(gorf.state.unknown_counts)
        for index = 1, math.min(count or 20, #rows) do
            local row = rows[index]
            C.print_info(string.format("%8d  $%04X  %s", row.count, row.address, C.label(row.address)))
        end
    end
    gorf.save_trace = function(path, count) return C.save_trace(path, count) end
    gorf.save_discovery = function(path) return C.save_discovery(path) end
    gorf.load_lst = function(path) return C.load_lst(path) end
    gorf.stop_core = function() C.remove_runtime_hooks() end

    return gorf
end

return C
