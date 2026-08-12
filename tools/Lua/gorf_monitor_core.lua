-- gorf_monitor_core.lua

local C = {}
C.module_name = "core"
C.api_version = 1
C.revision = "2.3.1-20260812"


-- At $0060 DSPATCH has fetched the target into HL and advanced BC past the
-- two-byte threaded entry.  Filtering on PC=$0060 excludes unrelated reads of
-- dispatcher ROM bytes from the trace.
local TERSE_DISPATCH_EXECUTION = 0x0060

-- At $0F37 the native music interpreter has completed LD A,(HL).  HL still
-- identifies the opcode byte and IY identifies one of the two music engines.
local MUSIC_OPCODE_EXECUTION = 0x0F37

-- These native primitives transfer control to a runtime-selected threaded
-- word.  When that destination is a colon definition, its _ENTER pushes the
-- caller's continuation onto IX.  They are indirect calls, not ordinary
-- primitives and not high-level entry points themselves.
local DYNAMIC_CALL_TARGETS = {
    [0x0468] = true, -- _CASES
    [0x1472] = true  -- _EXECUTE
}

local LOOP_ENTER_TARGET = 0x0244 -- _DO
local LOOP_EXIT_TARGETS = {
    [0x025F] = true, -- _LOOP
    [0x0397] = true  -- _plusLOOP
}

-- IX is shared by colon continuations, loop-control triples, and arbitrary
-- values moved with >R/R>.  These two standard TERSE primitives must therefore
-- be distinguished from ordinary call/return activity.
local RETURN_DATA_POP_TARGET = 0x00B4  -- _Rgt (R>)
local RETURN_DATA_PUSH_TARGET = 0x00C1 -- _gtR (>R)

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

function C.u16_direct(address)
    local low = C.u8_direct(address)
    local high = C.u8_direct(address + 1)
    return low | (high << 8)
end

function C.bcd_score(address)
    return string.format("%02X%02X%02X", C.u8(address + 2), C.u8(address + 1), C.u8(address))
end

function C.exact_symbol(address)
    address = address & 0xFFFF
    local imported = C.g.runtime.lst_symbols[address]
    if imported then return imported, "LST" end
    local builtin = C.g.data.symbols[address] or C.g.data.entries[address]
    if builtin then return builtin, "ASM" end
    return nil, nil
end

function C.annotation(address)
    local annotation = C.g.data.annotations and C.g.data.annotations[address & 0xFFFF]
    if type(annotation) == "table" then
        return annotation.description or annotation.name, annotation.confidence or "ANNOTATION"
    end
    if annotation then return annotation, "ANNOTATION" end
    return nil, nil
end

function C.label(address)
    local exact = C.exact_symbol(address)
    return exact or ("$" .. C.hex(address))
end

function C.target_decode(address, high_level)
    local exact, source = C.exact_symbol(address)
    local description, description_source = C.annotation(address)
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

        if high_level and b0 == 0xCF then
            local first_target = b1 | (b2 << 8)
            local first_name = C.exact_symbol(first_target)
            stream_preview = string.format("ENTER -> $%04X%s", first_target,
                first_name and (" " .. first_name) or "")
        else
            stream_preview = string.format("BYTES %02X %02X %02X", b0, b1, b2)
        end
    end

    return {
        exact_name = exact,
        exact_source = source,
        display_name = exact or string.format(high_level and "TERSE_$%04X" or "NATIVE_$%04X", address),
        class = high_level and "TERSE WORD" or "NATIVE PRIMITIVE",
        description = description,
        description_source = description and description_source or nil,
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
    local name = C.exact_symbol(best)
    if not name then return "$" .. C.hex(address) end
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

function C.return_depth(pointer)
    local base = C.g.data.address.RSP
    if pointer > base or pointer < 0xD000 or ((base - pointer) & 1) ~= 0 then return 0 end
    return (base - pointer) // 2
end

function C.parameter_depth(pointer)
    local base = C.g.data.address.PSP
    if pointer > base or pointer < 0xD000 or ((base - pointer) & 1) ~= 0 then return 0 end
    return (base - pointer) // 2
end

function C.rebuild_entry_order()
    local seen, order = {}, {}
    for address in pairs(C.g.data.entries) do seen[address] = true end
    for address in pairs(C.g.runtime.dynamic_entries) do seen[address] = true end
    for address in pairs(seen) do order[#order + 1] = address end
    table.sort(order)
    C.g.runtime.entry_order = order
end

function C.register_entry(address)
    address = address & 0xFFFF
    if C.g.runtime.dynamic_entries[address] then return end
    C.g.runtime.dynamic_entries[address] = true
    C.rebuild_entry_order()
end

function C.entry_context(address)
    local order = C.g.runtime.entry_order
    local low, high, best = 1, #order, nil
    while low <= high do
        local middle = (low + high) // 2
        if order[middle] <= address then
            best = order[middle]
            low = middle + 1
        else
            high = middle - 1
        end
    end
    if not best or ((address - best) & 0xFFFF) > 0x0400 then return nil end
    return { address = best, name = C.exact_symbol(best) or ("TERSE_$" .. C.hex(best)) }
end

-- IX is the real TERSE return-stack pointer.  Colon definitions contribute
-- two-byte continuations, DO loops contribute three cells, and >R may place an
-- arbitrary value there.  Raw cells are rebuilt on every dispatch; a small
-- address-keyed provenance map preserves only frame types that were directly
-- observed after the current trace was armed.
function C.stack_fingerprint(values)
    local hash = (0x811C9DC5 ~ #values) & 0xFFFFFFFF
    for _, value in ipairs(values) do
        hash = ((hash ~ (value & 0xFF)) * 0x01000193) & 0xFFFFFFFF
        hash = ((hash ~ ((value >> 8) & 0xFF)) * 0x01000193) & 0xFFFFFFFF
    end
    return hash
end

function C.stack_snapshot(pointer, base)
    local depth
    if base == C.g.data.address.RSP then
        depth = C.return_depth(pointer)
    else
        depth = C.parameter_depth(pointer)
    end
    local values = C.stack_words(pointer, base, depth)
    return values, depth, C.stack_fingerprint(values)
end

function C.is_loop_frame(values, index)
    if index + 2 > #values then return false end
    local loop_start = values[index + 2]
    if loop_start < 2 or loop_start > 0xBFFF then return false end
    return C.u16_direct(loop_start - 2) == LOOP_ENTER_TARGET
end

local function call_return_kind(owner, return_address, cell_address)
    local provenance = C.g.state.return_provenance[cell_address]
    if provenance == "return_data" then return nil end
    if provenance == "call" then
        return "observed", owner and owner.address or nil
    end
    if return_address < 2 then return nil end

    -- A direct colon call leaves its callee address in the threaded cell just
    -- before the saved continuation.  EXECUTE and CASES are the two known
    -- runtime-selected call sites; their preceding cell names the dispatcher
    -- primitive rather than the selected callee.
    local source_target = C.u16_direct((return_address - 2) & 0xFFFF)
    if C.u8_direct(source_target) == 0xCF then
        if owner and source_target == owner.address then
            return "direct", source_target
        end
        -- Tracing may be armed after an outer call has already pushed its
        -- continuation.  The preceding threaded cell plus an _ENTER opcode
        -- still proves a colon call even when live provenance and the current
        -- owner walk are unavailable.
        return "structural", source_target
    end
    if DYNAMIC_CALL_TARGETS[source_target] then
        return "dynamic", owner and owner.address or nil
    end
    return nil
end

-- Reconstruct typed IX frames.  Loop triples are recognized structurally,
-- directly observed >R values retain return_data provenance, and call cells
-- must either have observed call provenance or validate against their call
-- site.  Anything else remains unknown; it must not create a named frame or
-- change the caller context.
function C.reconstruct_call_stack(ip, ix, return_values)
    local values = return_values
    if not values then values = C.stack_snapshot(ix, C.g.data.address.RSP) end

    local call_frames, loop_frames, data_frames, unknown_frames, stack_frames = {}, {}, {}, {}, {}
    local context = C.entry_context(ip)
    local owner = context
    local index = 1
    while index <= #values do
        local cell_address = (ix + ((index - 1) * 2)) & 0xFFFF
        local provenance = C.g.state.return_provenance[cell_address]
        if provenance == "return_data" then
            local frame = {
                frame_type = "return_data",
                value = values[index],
                cell_address = cell_address,
                physical_slot = index,
                level = #data_frames + 1
            }
            data_frames[#data_frames + 1] = frame
            stack_frames[#stack_frames + 1] = frame
            index = index + 1
        elseif C.is_loop_frame(values, index) then
            local frame = {
                frame_type = "loop",
                index = values[index],
                limit = values[index + 1],
                loop_start = values[index + 2],
                physical_slot = index,
                context_address = owner and owner.address or nil,
                context_name = owner and owner.name or nil,
                cell_address = cell_address,
                level = #loop_frames + 1
            }
            loop_frames[#loop_frames + 1] = frame
            stack_frames[#stack_frames + 1] = frame
            index = index + 3
        else
            local value = values[index]
            local call_kind, call_address =
                call_return_kind(owner, value, cell_address)
            if call_kind then
                local frame_address = call_address or (owner and owner.address or nil)
                local frame = {
                    frame_type = "call",
                    address = frame_address,
                    name = frame_address and (C.exact_symbol(frame_address)
                        or ("TERSE_$" .. C.hex(frame_address)))
                        or "UNRESOLVED FRAME",
                    return_address = value,
                    call_site = (value - 2) & 0xFFFF,
                    call_kind = call_kind,
                    cell_address = cell_address,
                    physical_slot = index,
                    level = #call_frames + 1
                }
                call_frames[#call_frames + 1] = frame
                stack_frames[#stack_frames + 1] = frame
                owner = C.entry_context((value - 2) & 0xFFFF)
            else
                local frame = {
                    frame_type = "unknown",
                    value = value,
                    cell_address = cell_address,
                    physical_slot = index,
                    level = #unknown_frames + 1
                }
                unknown_frames[#unknown_frames + 1] = frame
                stack_frames[#stack_frames + 1] = frame
            end
            index = index + 1
        end
    end
    return call_frames, #values, context, loop_frames, stack_frames,
        data_frames, unknown_frames
end

function C.inline_detail(ip, target)
    local kind = C.g.data.inline_words[target]
    if not kind then return nil end
    if kind == "byte" then
        return "#$" .. C.hex(C.u8_direct(ip + 2), 2)
    elseif kind == "word" or kind == "address" then
        local value = C.u8_direct(ip + 2) | (C.u8_direct(ip + 3) << 8)
        local symbol = C.exact_symbol(value)
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

function C.dispatch_kind(target, high_level)
    if target == 0x0061 then return "return" end
    if DYNAMIC_CALL_TARGETS[target] then return "dynamic_call" end
    if high_level then return "call" end
    return "word"
end

function C.same_dispatch(left, right)
    if not left or not right then return false end
    return left.dispatcher_pc == right.dispatcher_pc
        and left.ip == right.ip
        and left.next_bc == right.next_bc
        and left.target == right.target
        and left.sp == right.sp
        and left.ix == right.ix
        and left.iy == right.iy
        and left.return_stack_fingerprint == right.return_stack_fingerprint
        and left.parameter_stack_fingerprint == right.parameter_stack_fingerprint
end

-- Classify the IX change caused by the event in `before`.  A positive delta
-- removes cells because IX grows toward its empty-stack base at RSP.
function C.transition_effect(before, after)
    if not before or not after then return "none", 0 end
    if after.repeated_state and after.repeated_of_sequence == before.sequence then
        return "repeated_state", 0
    end

    local delta = after.ix - before.ix
    if delta == 0 then return "none", 0 end
    if (delta & 1) ~= 0 then return "odd_stack_delta", delta end

    local cells = math.abs(delta) // 2
    if delta > 6 then return "nonlocal_unwind", cells end
    if before.target == LOOP_ENTER_TARGET and delta == -6 then
        return "loop_enter", cells
    end
    if LOOP_EXIT_TARGETS[before.target] and delta == 6 then
        return "loop_exit", cells
    end
    if before.target == RETURN_DATA_PUSH_TARGET and delta == -2 then
        return "return_data_push", cells
    end
    if before.target == RETURN_DATA_POP_TARGET and delta == 2 then
        return "return_data_pop", cells
    end
    if before.kind == "dynamic_call" and delta == -2 then
        return "dynamic_call", cells
    end
    if before.kind == "call" and delta == -2 then return "call", cells end
    if before.kind == "return" and delta == 2 then return "return", cells end
    return delta < 0 and "stack_push" or "stack_pop", cells
end

-- Update only provenance that was observed while this trace was active.  A
-- trace armed in the middle of a word may initially show unknown cells; this
-- is deliberate and safer than inventing calls from arbitrary IX values.
function C.update_return_provenance(before, after)
    if not before or not after then return end
    local delta = after.ix - before.ix
    if delta == 0 or (delta & 1) ~= 0 then return end

    local provenance = C.g.state.return_provenance
    if delta < 0 then
        for address = after.ix, before.ix - 2, 2 do
            provenance[address & 0xFFFF] = nil
        end
    else
        for address = before.ix, after.ix - 2, 2 do
            provenance[address & 0xFFFF] = nil
        end
    end

    local effect = C.transition_effect(before, after)
    if effect == "return_data_push" then
        provenance[after.ix & 0xFFFF] = "return_data"
    elseif effect == "call" or effect == "dynamic_call" then
        provenance[after.ix & 0xFFFF] = "call"
    end
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
    state.loop_stack = {}
    state.return_data_stack = {}
    state.unknown_return_stack = {}
    state.return_provenance = {}
    state.logged_discoveries = {}
    state.discovery_records = {}
    state.discovery_emissions = {}
    state.repeated_dispatch_states = 0
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

function C.discovery_mode(mode)
    if mode == nil then return C.g.config.discovery_mode or "unknown" end
    local valid = { unknown = true, all = true, off = true }
    assert(valid[mode], "discovery mode must be 'unknown', 'all', or 'off'")
    C.g.config.discovery_mode = mode
    C.print_info("[GORF MONITOR] discovery console: " .. mode)
    return mode
end

function C.record_discovery_decision(event, decoded)
    if decoded.exact_name then return nil end

    local state = C.g.state
    local mode = C.g.config.discovery_mode or "unknown"
    local category = decoded.description and "HYPOTHESIS" or "DISCOVERY"
    local decision
    if mode == "off" then
        decision = "suppressed_filter_off"
    elseif mode == "unknown" and decoded.description then
        decision = "suppressed_hypothesis"
    elseif not event.terse_stream_preview then
        decision = "suppressed_no_preview"
    elseif state.logged_discoveries[event.target] then
        decision = "already_emitted"
    else
        decision = "emitted"
        state.logged_discoveries[event.target] = true
    end

    local key = mode .. ":" .. C.hex(event.target)
    local record = state.discovery_records[key]
    if not record then
        record = {
            address = event.target,
            category = category,
            mode = mode,
            decision = decision,
            first_decision = decision,
            last_decision = decision,
            emitted = false,
            emitted_count = 0,
            already_emitted_count = 0,
            suppressed_count = 0,
            suppressed_hypothesis_count = 0,
            suppressed_filter_off_count = 0,
            suppressed_no_preview_count = 0,
            first_sequence = event.sequence,
            last_sequence = event.sequence,
            first_time = event.time,
            last_time = event.time,
            first_ip = event.ip,
            first_context = event.reconstructed_context,
            preview = event.terse_stream_preview,
            occurrences = 0
        }
        state.discovery_records[key] = record
        state.discovery_emissions[#state.discovery_emissions + 1] = record
    end
    record.occurrences = record.occurrences + 1
    record.last_sequence = event.sequence
    record.last_time = event.time
    record.last_decision = decision

    if decision == "emitted" then
        record.emitted = true
        record.emitted_count = record.emitted_count + 1
    elseif decision == "already_emitted" then
        record.already_emitted_count = record.already_emitted_count + 1
    else
        record.suppressed_count = record.suppressed_count + 1
        local count_name = decision .. "_count"
        if record[count_name] ~= nil then
            record[count_name] = record[count_name] + 1
        end
    end

    if decision == "emitted" then
        print(string.format("[%s] IP: $%04X -> Target: $%04X | %s (Context: %s)",
            category, event.ip, event.target, event.terse_stream_preview,
            event.reconstructed_context or "NONE"))
    end
    return record
end

function C.on_dispatch()
    if not C.g.running or not C.g.config.exact_trace then return end
    local ok, message = pcall(function()
        local state = C.g.state
        local pc = C.register_value("PC")
        if pc ~= TERSE_DISPATCH_EXECUTION then return end
        local next_bc = C.register_value("BC")
        local ip = (next_bc - 2) & 0xFFFF
        local target = C.register_value("HL")
        local sp = C.register_value("SP")
        local ix = C.register_value("IX")
        local iy = C.register_value("IY")

        -- At the first dispatch inside a colon definition, BC points at the
        -- first threaded cell and the preceding byte is its _ENTER opcode.
        if ip > 0 and C.u8_direct(ip - 1) == 0xCF then C.register_entry(ip - 1) end

        local high_level = C.u8_direct(target) == 0xCF
        if high_level then C.register_entry(target) end
        local decoded = C.target_decode(target, high_level)
        local name = decoded.exact_name or decoded.display_name
        local return_values, return_depth, return_fingerprint =
            C.stack_snapshot(ix, C.g.data.address.RSP)
        local parameter_values, parameter_depth, parameter_fingerprint =
            C.stack_snapshot(sp, C.g.data.address.PSP)
        local previous = state.last_dispatch
        C.update_return_provenance(previous, { ix = ix, repeated_state = false })
        local call_stack, physical_return_depth, current, loop_stack,
            return_stack_frames, return_data_stack, unknown_return_stack =
            C.reconstruct_call_stack(ip, ix, return_values)
        local stack_top = {}
        for index = 1, math.min(5, #parameter_values) do
            stack_top[index] = parameter_values[index]
        end
        local return_stack_top = {}
        for index = 1, math.min(8, #return_values) do
            return_stack_top[index] = return_values[index]
        end
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
            description_source = decoded.description_source,
            nearest_symbol = decoded.nearest_symbol,
            terse_stream_preview = decoded.terse_stream_preview,
            detail = C.inline_detail(ip, target),
            reconstructed_context = current and current.name or nil,
            reconstructed_context_address = current and current.address or nil,
            reconstructed_stream_offset = current and ((ip - current.address) & 0xFFFF) or nil,
            reconstructed_call_depth = #call_stack,
            reconstructed_loop_depth = #loop_stack,
            reconstructed_return_data_depth = #return_data_stack,
            reconstructed_unknown_return_depth = #unknown_return_stack,
            reconstructed_physical_return_depth = physical_return_depth,
            reconstructed_parameter_depth = parameter_depth,
            sp = sp,
            ix = ix,
            iy = iy,
            next_bc = next_bc,
            dispatcher_pc = pc,
            dispatcher = {
                pc = pc, ip = ip, next_bc = next_bc, target = target,
                sp = sp, ix = ix, iy = iy,
                parameter_depth = parameter_depth,
                return_depth = physical_return_depth,
                call_depth = #call_stack,
                loop_depth = #loop_stack,
                return_data_depth = #return_data_stack,
                unknown_return_depth = #unknown_return_stack
            },
            call_stack = call_stack,
            loop_stack = loop_stack,
            return_data_stack = return_data_stack,
            unknown_return_stack = unknown_return_stack,
            return_stack_frames = return_stack_frames,
            return_stack_top = return_stack_top,
            return_stack_fingerprint = return_fingerprint,
            parameter_stack_fingerprint = parameter_fingerprint,
            stack = stack_top,
            kind = C.dispatch_kind(target, high_level)
        }

        if C.same_dispatch(previous, event) then
            event.repeated_state = true
            event.repeated_of_sequence = previous.sequence
            state.repeated_dispatch_states = (state.repeated_dispatch_states or 0) + 1
        else
            event.repeated_state = false
        end

        if previous then
            previous.control_effect, previous.control_cells = C.transition_effect(previous, event)
            previous.next_sequence = event.sequence
        end

        state.total_words = event.sequence
        state.dispatch_since_frame = state.dispatch_since_frame + 1
        state.word_counts[target] = (state.word_counts[target] or 0) + 1
        if not decoded.exact_name then
            state.unknown_counts[target] = (state.unknown_counts[target] or 0) + 1
        end
        state.call_stack = call_stack
        state.loop_stack = loop_stack
        state.return_data_stack = return_data_stack
        state.unknown_return_stack = unknown_return_stack
        state.last_dispatch = event
        C.ring_push(state.trace, event)

        C.record_discovery_decision(event, decoded)
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
            reconstructed_loop_stack = state.loop_stack,
            reconstructed_return_data_stack = state.return_data_stack,
            reconstructed_unknown_return_stack = state.unknown_return_stack,
            reconstructed_parameter_depth = state.last_dispatch
                and state.last_dispatch.reconstructed_parameter_depth or 0,
            reconstructed_return_cells = state.last_dispatch
                and state.last_dispatch.reconstructed_physical_return_depth or 0,
            reconstructed_call_depth = state.last_dispatch
                and state.last_dispatch.reconstructed_call_depth or 0,
            reconstructed_loop_depth = state.last_dispatch
                and state.last_dispatch.reconstructed_loop_depth or 0,
            reconstructed_return_data_depth = state.last_dispatch
                and state.last_dispatch.reconstructed_return_data_depth or 0,
            reconstructed_unknown_return_depth = state.last_dispatch
                and state.last_dispatch.reconstructed_unknown_return_depth or 0,
            dispatcher = state.last_dispatch and state.last_dispatch.dispatcher or nil
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

local function append_unique(list, value)
    for _, existing in ipairs(list) do
        if existing == value then return false end
    end
    list[#list + 1] = value
    return true
end

local function choose_lst_label(address, aliases, definitions)
    local defined = definitions[address]
    if defined and #defined > 0 then return defined[1] end
    local builtin = C.g.data.symbols[address] or C.g.data.entries[address]
    if builtin then
        for _, label in ipairs(aliases) do
            if label == builtin then return label end
        end
    end
    return aliases[1]
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
        event.description_source = decoded.description_source
        event.nearest_symbol = decoded.nearest_symbol
        event.terse_stream_preview = decoded.terse_stream_preview
        if event.reconstructed_context_address then
            event.reconstructed_context = C.exact_symbol(event.reconstructed_context_address)
                or ("TERSE_$" .. C.hex(event.reconstructed_context_address))
        end
    end
    for _, frame in ipairs(C.g.state.call_stack) do
        local exact = frame.address and C.exact_symbol(frame.address) or nil
        if exact then frame.name = exact end
    end
    for _, frame in ipairs(C.g.state.loop_stack or {}) do
        local exact = frame.context_address and C.exact_symbol(frame.context_address) or nil
        if exact then frame.context_name = exact end
    end
    local unknown = {}
    for address, count in pairs(C.g.state.word_counts) do
        if not C.exact_symbol(address) then
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
    local aliases, definitions = {}, {}
    local in_symbol_table = false

    local function record_label(address_text, label, definition)
        if not address_text or not label or #address_text > 4 then return end
        local address = tonumber(address_text, 16)
        if not address then return end
        aliases[address] = aliases[address] or {}
        append_unique(aliases[address], label)
        if definition then
            definitions[address] = definitions[address] or {}
            append_unique(definitions[address], label)
        end
    end

    for source_line in file:lines() do
        if source_line:lower():find("symbol table:", 1, true) then
            in_symbol_table = true
        end

        -- zmac listing layouts vary by release.  Newer versions delimit the
        -- address/byte and source fields with tabs; older versions use spaces.
        local address_text, label = source_line:match(
            "\t([%x]+)[^\t]*\t%s*([%a_.$?@][%w_.$?@]*):")
        if not address_text then
            address_text, label = source_line:match(
                "\t([%x]+)%s+[%x]+%s+([%a_.$?@][%w_.$?@]*):")
        end
        if not address_text then
            address_text, label = source_line:match(
                "\t([%x]+)%s+([%a_.$?@][%w_.$?@]*):")
        end
        record_label(address_text, label, true)

        -- EQU labels are exact source symbols, but not code/data definitions.
        -- Keeping them out of definitions lets a real program label win when
        -- a hardware constant shares the same numeric address.
        local equ_address, equ_label = source_line:match(
            "\t([%x]+)[^\t]*\t%s*([%a_.$?@][%w_.$?@]*)%s+EQU")
        if not equ_address then
            equ_address, equ_label = source_line:match(
                "\t([%x]+)%s+([%a_.$?@][%w_.$?@]*)%s+EQU")
        end
        record_label(equ_address, equ_label, false)

        if in_symbol_table then
            label, address_text = source_line:match(
                "^%s*([%a_.$?@][%w_.$?@]*)%s+=%s*([%x]+)%s+%d+%s*$")
            if not label then
                label, address_text = source_line:match(
                    "^%s*([%a_.$?@][%w_.$?@]*)%s+([%x]+)%s+%d+%s*$")
            end
            record_label(address_text, label, false)
        end
    end
    file:close()

    local loaded, alias_count, confirmed, superseded = 0, 0, 0, 0
    local selected = {}
    for address, names in pairs(aliases) do
        selected[address] = choose_lst_label(address, names, definitions)
        loaded = loaded + 1
        alias_count = alias_count + #names
        local builtin = C.g.data.symbols[address] or C.g.data.entries[address]
        if builtin then
            if builtin == selected[address] then confirmed = confirmed + 1
            else superseded = superseded + 1 end
        end
    end
    if loaded == 0 then
        C.print_info("[GORF MONITOR] LST: no recognizable labels; previous symbols retained")
        return {
            loaded = 0, aliases = 0, confirmed = 0, superseded = 0,
            retained = true
        }
    end

    C.g.runtime.lst_symbols = selected
    C.g.runtime.lst_aliases = aliases
    C.rebuild_symbol_order()
    C.refresh_symbol_decodes()
    C.print_info(string.format(
        "[GORF MONITOR] LST: %d addresses, %d labels; %d ASM names confirmed, %d superseded",
        loaded, alias_count, confirmed, superseded))
    return {
        loaded = loaded, aliases = alias_count,
        confirmed = confirmed, superseded = superseded
    }
end

local function return_frames_text(frames)
    local values = {}
    for _, frame in ipairs(frames or {}) do
        if frame.frame_type == "call" then
            values[#values + 1] = string.format("CALL:%s@%04X[%s]",
                frame.name or "UNRESOLVED", frame.return_address or 0,
                frame.call_kind or "unknown")
        elseif frame.frame_type == "loop" then
            values[#values + 1] = string.format("LOOP:%04X/%04X@%04X",
                frame.index or 0, frame.limit or 0, frame.loop_start or 0)
        elseif frame.frame_type == "return_data" then
            values[#values + 1] = string.format("DATA:%04X", frame.value or 0)
        else
            values[#values + 1] = string.format("UNKNOWN:%04X", frame.value or 0)
        end
    end
    return table.concat(values, " ")
end

function C.save_trace(path, count)
    assert(type(path) == "string" and path ~= "", "trace path is required")
    local file, message = io.open(path, "w")
    assert(file, message)
    file:write("sequence,time,stream_address,next_bc,target,decoded_name,decoded_source,target_class,kind,repeated_state,repeated_of_sequence,return_stack_fingerprint,parameter_stack_fingerprint,control_effect,control_cells,decoded_description,nearest_symbol,reconstructed_context,reconstructed_context_address,reconstructed_stream_offset,detail,sp,ix,iy,reconstructed_parameter_depth,reconstructed_physical_return_depth,reconstructed_call_depth,reconstructed_loop_depth,reconstructed_return_data_depth,reconstructed_unknown_return_depth,parameter_stack_top,return_stack_top,loop_frames,return_stack_frames\n")
    local rows = C.ring_recent(C.g.state.trace, count or C.g.state.trace.count)
    for index = #rows, 1, -1 do
        local event = rows[index]
        local stack = {}
        for _, value in ipairs(event.stack) do stack[#stack + 1] = C.hex(value) end
        local return_stack = {}
        for _, value in ipairs(event.return_stack_top or {}) do
            return_stack[#return_stack + 1] = C.hex(value)
        end
        local loops = {}
        for _, frame in ipairs(event.loop_stack or {}) do
            loops[#loops + 1] = string.format("%04X/%04X@$%04X",
                frame.index, frame.limit, frame.loop_start)
        end
        file:write(table.concat({
            event.sequence,
            string.format("%.6f", event.time),
            C.hex(event.ip),
            C.hex(event.next_bc),
            C.hex(event.target),
            C.csv_field(event.decoded_name),
            C.csv_field(event.decoded_source),
            C.csv_field(event.target_class),
            C.csv_field(event.kind),
            event.repeated_state and "true" or "false",
            event.repeated_of_sequence or "",
            string.format("%08X", event.return_stack_fingerprint or 0),
            string.format("%08X", event.parameter_stack_fingerprint or 0),
            C.csv_field(event.control_effect),
            event.control_cells or "",
            C.csv_field(event.decoded_description),
            C.csv_field(event.nearest_symbol),
            C.csv_field(event.reconstructed_context),
            event.reconstructed_context_address and C.hex(event.reconstructed_context_address) or "",
            event.reconstructed_stream_offset and C.hex(event.reconstructed_stream_offset) or "",
            C.csv_field(event.detail),
            C.hex(event.sp),
            C.hex(event.ix),
            C.hex(event.iy),
            event.reconstructed_parameter_depth,
            event.reconstructed_physical_return_depth,
            event.reconstructed_call_depth,
            event.reconstructed_loop_depth,
            event.reconstructed_return_data_depth,
            event.reconstructed_unknown_return_depth,
            C.csv_field(table.concat(stack, " ")),
            C.csv_field(table.concat(return_stack, " ")),
            C.csv_field(table.concat(loops, " ")),
            C.csv_field(return_frames_text(event.return_stack_frames))
        }, ","), "\n")
    end
    file:close()
    C.print_info(string.format("[GORF MONITOR] wrote %d trace rows to %s", #rows, path))
    return #rows
end

function C.save_discovery_emissions(path)
    assert(type(path) == "string" and path ~= "", "discovery emissions path is required")
    local file, message = io.open(path, "w")
    assert(file, message)
    file:write(table.concat({
        "address", "category", "discovery_mode", "first_decision",
        "last_decision", "emitted", "emitted_count", "already_emitted_count",
        "suppressed_count", "suppressed_hypothesis_count",
        "suppressed_filter_off_count", "suppressed_no_preview_count",
        "occurrences", "first_sequence", "last_sequence", "first_time",
        "last_time", "first_ip", "first_context", "preview"
    }, ","), "\n")

    local rows = {}
    for _, record in ipairs(C.g.state.discovery_emissions or {}) do
        rows[#rows + 1] = record
    end
    table.sort(rows, function(left, right)
        if left.first_sequence == right.first_sequence then
            if left.address == right.address then return left.mode < right.mode end
            return left.address < right.address
        end
        return left.first_sequence < right.first_sequence
    end)

    for _, record in ipairs(rows) do
        file:write(table.concat({
            C.hex(record.address),
            C.csv_field(record.category),
            C.csv_field(record.mode),
            C.csv_field(record.first_decision),
            C.csv_field(record.last_decision),
            record.emitted and "true" or "false",
            record.emitted_count,
            record.already_emitted_count,
            record.suppressed_count,
            record.suppressed_hypothesis_count,
            record.suppressed_filter_off_count,
            record.suppressed_no_preview_count,
            record.occurrences,
            record.first_sequence,
            record.last_sequence,
            string.format("%.6f", record.first_time),
            string.format("%.6f", record.last_time),
            C.hex(record.first_ip),
            C.csv_field(record.first_context),
            C.csv_field(record.preview)
        }, ","), "\n")
    end
    file:close()
    C.print_info(string.format(
        "[GORF MONITOR] wrote %d discovery audit rows to %s", #rows, path))
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
        taps = {}, subscriptions = {}, registers = {}, symbol_order = {}, entry_order = {},
        lst_symbols = {}, lst_aliases = {}, dynamic_entries = {}
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
    C.rebuild_entry_order()

    gorf.state = {
        warnings = {}, reported_errors = {}, total_words = 0, dispatch_since_frame = 0,
        frame_words = 0, word_rate = 0, word_counts = {}, unknown_counts = {},
        logged_discoveries = {}, discovery_records = {}, discovery_emissions = {},
        repeated_dispatch_states = 0,
        call_stack = {}, loop_stack = {}, return_data_stack = {},
        unknown_return_stack = {}, return_provenance = {},
        trace = C.ring(gorf.config.trace_capacity),
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
    gorf.save_discovery_emissions = function(path)
        return C.save_discovery_emissions(path)
    end
    gorf.load_lst = function(path) return C.load_lst(path) end
    gorf.discovery = function(mode) return C.discovery_mode(mode) end
    gorf.stop_core = function() C.remove_runtime_hooks() end

    return gorf
end

return C
