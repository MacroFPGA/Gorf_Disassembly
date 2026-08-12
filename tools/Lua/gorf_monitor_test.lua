-- gorf_monitor_test.lua
-- Guided acceptance and trace capture for Gorf Monitor 2.3.1.

local REQUIRED_MONITOR_REVISION = "2.3.1-20260812"
local REQUIRED_CORE_REVISION = "2.3.1-20260812"
local REQUIRED_HUD_REVISION = "2.3.0-20260812"
local RUNNER_VERSION = "1.3.1"
local RUNNER_REVISION = "1.3.1-20260812"
local TRACE_CAPACITY = 131072
local SUMMARY_LIMIT = 30
local RAW_STACK_CELL_LIMIT = 64

local previous_runner = rawget(_G, "GorfMonitorTest")
if previous_runner and previous_runner.abort then
    pcall(previous_runner.abort, true)
end

local G = rawget(_G, "GorfMonitor")
assert(G and G.running, "Gorf Monitor must be loaded before the test runner")
assert(G.revision == REQUIRED_MONITOR_REVISION,
    string.format("test runner requires Gorf Monitor %s; loaded %s",
        REQUIRED_MONITOR_REVISION, tostring(G.revision)))
assert(G.module_revisions and G.module_revisions.core == REQUIRED_CORE_REVISION,
    string.format("test runner requires core %s; loaded %s",
        REQUIRED_CORE_REVISION,
        tostring(G.module_revisions and G.module_revisions.core)))
assert(G.module_revisions and G.module_revisions.hud == REQUIRED_HUD_REVISION,
    string.format("test runner requires HUD %s; loaded %s",
        REQUIRED_HUD_REVISION,
        tostring(G.module_revisions and G.module_revisions.hud)))

local T = {
    version = RUNNER_VERSION,
    revision = RUNNER_REVISION,
    phase = "loading",
    test_index = 1,
    active = true,
    skipped = {},
    shortcuts = {},
    original = {
        exact_trace = G.config.exact_trace,
        discovery_mode = G.config.discovery_mode,
        trace_capacity = G.config.trace_capacity
    }
}

local separator = package.config:sub(1, 1)
local is_windows = separator == "\\"

local tests = {
    {
        id = "01_attract",
        title = "Stable attract mode",
        discovery = "off",
        ready = "Navigate to a stable attract screen.",
        capture = "Let attract mode run for about one second, then return to the console and enter gtack()."
    },
    {
        id = "02_coin_select",
        title = "Coin insertion transition",
        discovery = "off",
        ready = "Reach INSERT COIN immediately before adding a coin.",
        capture = "Switch to the game, press 5 once, wait until the player-selection screen settles, then return to the console and enter gtack()."
    },
    {
        id = "03_astro_start",
        title = "Player start through Astro Battles formation",
        discovery = "off",
        ready = "Reach the player-selection screen immediately before pressing Player 1 Start.",
        capture = "Switch to the game, press Player 1 Start, wait until the Astro Battles formation appears, then return to the console and enter gtack()."
    },
    {
        id = "04_unknown_filter",
        title = "Unknown-only filter during Astro gameplay",
        discovery = "unknown",
        ready = "Reach stable Astro Battles gameplay with the ship under player control.",
        capture = "Move left and right and fire for three to five seconds, then return to the console and enter gtack(). Only genuine DISCOVERY lines should print."
    },
    {
        id = "05_all_filter",
        title = "All-filter repeat during Astro gameplay",
        discovery = "all",
        ready = "Reach another stable Astro Battles interval comparable to test 04.",
        capture = "Repeat the same left/right/fire pattern for three to five seconds, then return to the console and enter gtack(). HYPOTHESIS and genuine DISCOVERY lines may print."
    },
    {
        id = "06_return_data",
        title = "Mid-capture IX reconstruction and optional >R/R> provenance",
        discovery = "off",
        ready = "Reach any stable attract interval. The capture may begin inside an already-active chain; test 6 verifies that source-backed outer continuations are reconstructed without live provenance.",
        capture = "Let attract mode run for several seconds, then return to the console and enter gtack(). The summary reports structural call recovery and any optional GNAME, >R, or R> observations."
    }
}

local function out(message)
    print("[GORF TEST] " .. tostring(message))
end

local function hex(value)
    return value and string.format("%04X", value & 0xFFFF) or ""
end

local function hex32(value)
    return value and string.format("%08X", value & 0xFFFFFFFF) or ""
end

local function csv(value)
    local text = value == nil and "" or tostring(value)
    if text:find('[,\"\r\n]') then
        return '"' .. text:gsub('"', '""') .. '"'
    end
    return text
end

local function path(name)
    return T.output_directory .. separator .. name
end

local function machine()
    local current_manager = rawget(_G, "manager")
    return current_manager and current_manager.machine or nil
end

local function debugger_manager()
    local current_machine = machine()
    return current_machine and current_machine.debugger or nil
end

local function control_status()
    local current_machine = machine()
    local debugger = debugger_manager()
    return current_machine and tostring(current_machine.paused) or "unavailable",
        debugger and tostring(debugger.execution_state) or "disabled"
end

local function control_call(action, callback)
    local ok, message = pcall(callback)
    if not ok then
        error(string.format("cannot %s MAME: %s", action, tostring(message)))
    end
end

local function create_output_directory()
    local stamp = os.date("%Y%m%d-%H%M%S")
    local root = "zout" .. separator .. "gorf_monitor_tests"
    T.output_directory = root .. separator .. "run-" .. stamp

    local command
    if is_windows then
        command = 'mkdir "' .. T.output_directory:gsub('"', '""') .. '" >NUL 2>NUL'
    else
        command = "mkdir -p '" .. T.output_directory:gsub("'", "'\\''") .. "'"
    end
    pcall(os.execute, command)

    local manifest, message = io.open(path("manifest.txt"), "w")
    assert(manifest, "cannot create test output directory: " .. tostring(message))
    T.manifest = manifest
end

local function manifest_line(text)
    T.manifest:write(tostring(text), "\n")
    T.manifest:flush()
end

local function chronological_trace()
    local recent = G.recent(TRACE_CAPACITY)
    local rows = {}
    for index = #recent, 1, -1 do
        rows[#rows + 1] = recent[index]
    end
    return rows
end

local function raw_stack_words(pointer, base)
    local values = {}
    if not pointer or pointer > base or pointer < 0xD000
            or ((base - pointer) & 1) ~= 0 then
        return values
    end
    local depth = math.min((base - pointer) // 2, RAW_STACK_CELL_LIMIT)
    for index = 0, depth - 1 do
        values[#values + 1] = G.core.u16(pointer + index * 2)
    end
    return values
end

local function words_text(values)
    local result = {}
    for _, value in ipairs(values or {}) do
        result[#result + 1] = hex(value)
    end
    return table.concat(result, " ")
end

local function loop_frames_text(frames)
    local result = {}
    for _, frame in ipairs(frames or {}) do
        result[#result + 1] = string.format("%04X/%04X@%04X",
            frame.index, frame.limit, frame.loop_start)
    end
    return table.concat(result, " ")
end

local function typed_frames_text(frames)
    local result = {}
    for _, frame in ipairs(frames or {}) do
        if frame.frame_type == "call" then
            result[#result + 1] = string.format("CALL:%s@%04X[%s]",
                frame.name or "UNRESOLVED", frame.return_address or 0,
                frame.call_kind or "unknown")
        elseif frame.frame_type == "loop" then
            result[#result + 1] = string.format("LOOP:%04X/%04X@%04X",
                frame.index or 0, frame.limit or 0, frame.loop_start or 0)
        elseif frame.frame_type == "return_data" then
            result[#result + 1] = string.format("DATA:%04X", frame.value or 0)
        else
            result[#result + 1] = string.format("UNKNOWN:%04X", frame.value or 0)
        end
    end
    return table.concat(result, " ")
end

local function changed_words(before, after, pointer_name, cells_name)
    local before_pointer = before[pointer_name]
    local after_pointer = after[pointer_name]
    local delta = after_pointer - before_pointer
    local values = {}
    if delta < 0 and (delta & 1) == 0 then
        for index = 1, math.min((-delta) // 2, #(after[cells_name] or {})) do
            values[#values + 1] = after[cells_name][index]
        end
    elseif delta > 0 and (delta & 1) == 0 then
        for index = 1, math.min(delta // 2, #(before[cells_name] or {})) do
            values[#values + 1] = before[cells_name][index]
        end
    end
    return words_text(values)
end

local function stack_action(before, after)
    local delta = after - before
    if delta == 0 then return "NONE" end
    if (delta & 1) ~= 0 then return string.format("ODD_DELTA_%+d", delta) end
    if delta < 0 then return "PUSH " .. tostring((-delta) // 2) end
    return "POP " .. tostring(delta // 2)
end

local function save_transitions(test, rows)
    local file, message = io.open(path(test.id .. "_transitions.csv"), "w")
    assert(file, message)
    file:write(table.concat({
        "from_sequence", "to_sequence", "executed_stream", "executed_target",
        "executed_name", "executed_kind", "control_effect", "control_cells",
        "executed_repeated_state", "executed_repeated_of_sequence",
        "next_repeated_state", "return_fingerprint_before",
        "return_fingerprint_after", "parameter_fingerprint_before",
        "parameter_fingerprint_after", "physical_return_depth_before",
        "physical_return_depth_after", "logical_call_depth_before",
        "logical_call_depth_after", "loop_depth_before", "loop_depth_after",
        "return_data_depth_before", "return_data_depth_after",
        "unknown_return_depth_before", "unknown_return_depth_after",
        "context", "ix_before", "ix_after",
        "ix_delta_bytes", "ix_action", "ix_changed_cells", "ix_before_cells",
        "ix_after_cells", "sp_before", "sp_after", "sp_delta_bytes", "sp_action",
        "sp_changed_cells", "sp_before_cells", "sp_after_cells", "next_stream",
        "next_target", "next_name"
    }, ","), "\n")

    for index = 1, #rows - 1 do
        local before, after = rows[index], rows[index + 1]
        local effect, cells = before.control_effect, before.control_cells
        if not effect then
            effect, cells = G.core.transition_effect(before, after)
        end
        file:write(table.concat({
            before.sequence,
            after.sequence,
            hex(before.ip),
            hex(before.target),
            csv(before.decoded_name or before.name),
            csv(before.kind),
            csv(effect),
            cells or "",
            before.repeated_state and "true" or "false",
            before.repeated_of_sequence or "",
            after.repeated_state and "true" or "false",
            hex32(before.return_stack_fingerprint),
            hex32(after.return_stack_fingerprint),
            hex32(before.parameter_stack_fingerprint),
            hex32(after.parameter_stack_fingerprint),
            before.reconstructed_physical_return_depth or "",
            after.reconstructed_physical_return_depth or "",
            before.reconstructed_call_depth or "",
            after.reconstructed_call_depth or "",
            before.reconstructed_loop_depth or "",
            after.reconstructed_loop_depth or "",
            before.reconstructed_return_data_depth or "",
            after.reconstructed_return_data_depth or "",
            before.reconstructed_unknown_return_depth or "",
            after.reconstructed_unknown_return_depth or "",
            csv(before.reconstructed_context),
            hex(before.ix),
            hex(after.ix),
            after.ix - before.ix,
            csv(stack_action(before.ix, after.ix)),
            csv(changed_words(before, after, "ix", "raw_ix_cells")),
            csv(words_text(before.raw_ix_cells)),
            csv(words_text(after.raw_ix_cells)),
            hex(before.sp),
            hex(after.sp),
            after.sp - before.sp,
            csv(stack_action(before.sp, after.sp)),
            csv(changed_words(before, after, "sp", "raw_sp_cells")),
            csv(words_text(before.raw_sp_cells)),
            csv(words_text(after.raw_sp_cells)),
            hex(after.ip),
            hex(after.target),
            csv(after.decoded_name or after.name)
        }, ","), "\n")
    end
    file:close()
    return math.max(0, #rows - 1)
end

local function save_diagnostic_trace(test, rows)
    local file, message = io.open(path(test.id .. "_diagnostic.csv"), "w")
    assert(file, message)
    file:write(table.concat({
        "sequence", "time", "stream_address", "next_bc", "target", "decoded_name",
        "target_class", "kind", "repeated_state", "repeated_of_sequence",
        "return_stack_fingerprint", "parameter_stack_fingerprint",
        "control_effect", "control_cells", "context", "detail", "sp", "sp_depth",
        "sp_cells", "ix", "ix_depth", "physical_return_depth",
        "logical_call_depth", "loop_depth", "return_data_depth",
        "unknown_return_depth", "ix_cells", "loop_frames",
        "typed_return_frames", "iy"
    }, ","), "\n")
    for _, event in ipairs(rows) do
        file:write(table.concat({
            event.sequence,
            string.format("%.6f", event.time),
            hex(event.ip),
            hex(event.next_bc),
            hex(event.target),
            csv(event.decoded_name or event.name),
            csv(event.target_class),
            csv(event.kind),
            event.repeated_state and "true" or "false",
            event.repeated_of_sequence or "",
            hex32(event.return_stack_fingerprint),
            hex32(event.parameter_stack_fingerprint),
            csv(event.control_effect),
            event.control_cells or "",
            csv(event.reconstructed_context),
            csv(event.detail),
            hex(event.sp),
            #(event.raw_sp_cells or {}),
            csv(words_text(event.raw_sp_cells)),
            hex(event.ix),
            #(event.raw_ix_cells or {}),
            event.reconstructed_physical_return_depth or "",
            event.reconstructed_call_depth or "",
            event.reconstructed_loop_depth or "",
            event.reconstructed_return_data_depth or "",
            event.reconstructed_unknown_return_depth or "",
            csv(words_text(event.raw_ix_cells)),
            csv(loop_frames_text(event.loop_stack)),
            csv(typed_frames_text(event.return_stack_frames)),
            hex(event.iy)
        }, ","), "\n")
    end
    file:close()
    return #rows
end

local function capture_metrics(rows, emissions)
    local metrics = {
        dynamic_calls = 0,
        gname_dispatches = 0,
        return_data_push_words = 0,
        return_data_pop_words = 0,
        return_data_pushes = 0,
        return_data_pops = 0,
        maximum_return_data_depth = 0,
        maximum_unknown_return_depth = 0,
        structural_call_frame_observations = 0,
        maximum_structural_call_depth = 0,
        repeated_states = 0,
        nonlocal_unwinds = 0,
        discovery_unique_targets = 0,
        discovery_emitted_targets = 0,
        discovery_suppressed_targets = 0,
        discovery_emitted_count = 0,
        discovery_already_emitted_count = 0,
        discovery_suppressed_count = 0
    }
    for _, event in ipairs(rows) do
        if event.kind == "dynamic_call" then
            metrics.dynamic_calls = metrics.dynamic_calls + 1
        end
        if event.target == 0x09CD then
            metrics.gname_dispatches = metrics.gname_dispatches + 1
        elseif event.target == 0x00C1 then
            metrics.return_data_push_words = metrics.return_data_push_words + 1
        elseif event.target == 0x00B4 then
            metrics.return_data_pop_words = metrics.return_data_pop_words + 1
        end
        if event.control_effect == "return_data_push" then
            metrics.return_data_pushes = metrics.return_data_pushes + 1
        elseif event.control_effect == "return_data_pop" then
            metrics.return_data_pops = metrics.return_data_pops + 1
        end
        metrics.maximum_return_data_depth = math.max(
            metrics.maximum_return_data_depth,
            event.reconstructed_return_data_depth or 0)
        metrics.maximum_unknown_return_depth = math.max(
            metrics.maximum_unknown_return_depth,
            event.reconstructed_unknown_return_depth or 0)
        local structural_depth = 0
        for _, frame in ipairs(event.return_stack_frames or {}) do
            if frame.frame_type == "call" and frame.call_kind == "structural" then
                structural_depth = structural_depth + 1
            end
        end
        metrics.structural_call_frame_observations =
            metrics.structural_call_frame_observations + structural_depth
        metrics.maximum_structural_call_depth = math.max(
            metrics.maximum_structural_call_depth, structural_depth)
        if event.repeated_state then
            metrics.repeated_states = metrics.repeated_states + 1
        end
        if event.control_effect == "nonlocal_unwind" then
            metrics.nonlocal_unwinds = metrics.nonlocal_unwinds + 1
        end
    end
    for _, record in ipairs(emissions or {}) do
        metrics.discovery_unique_targets = metrics.discovery_unique_targets + 1
        if (record.emitted_count or 0) > 0 then
            metrics.discovery_emitted_targets = metrics.discovery_emitted_targets + 1
        end
        if (record.suppressed_count or 0) > 0 then
            metrics.discovery_suppressed_targets =
                metrics.discovery_suppressed_targets + 1
        end
        metrics.discovery_emitted_count = metrics.discovery_emitted_count
            + (record.emitted_count or 0)
        metrics.discovery_already_emitted_count =
            metrics.discovery_already_emitted_count
            + (record.already_emitted_count or 0)
        metrics.discovery_suppressed_count = metrics.discovery_suppressed_count
            + (record.suppressed_count or 0)
    end
    return metrics
end

local function save_summary(test, trace_rows, transition_rows, discovery_rows,
        emission_rows, dropped_rows, metrics)
    local file, message = io.open(path(test.id .. "_summary.txt"), "w")
    assert(file, message)
    file:write("GORF MONITOR TEST CAPTURE\n")
    file:write("runner version: ", T.version, "\n")
    file:write("runner revision: ", T.revision, "\n")
    file:write("monitor: ", G.revision, "\n")
    file:write("core: ", tostring(G.module_revisions.core), "\n")
    file:write("test: ", test.id, " - ", test.title, "\n")
    file:write("discovery mode: ", test.discovery, "\n")
    file:write("observed dispatches: ", tostring(G.state.total_words), "\n")
    file:write("saved trace rows: ", tostring(trace_rows), "\n")
    file:write("dropped trace rows: ", tostring(dropped_rows), "\n")
    file:write("saved transition rows: ", tostring(transition_rows), "\n")
    file:write("non-exact target rows: ", tostring(discovery_rows), "\n")
    file:write("discovery audit rows: ", tostring(emission_rows), "\n")
    file:write("discovery unique targets: ", tostring(metrics.discovery_unique_targets), "\n")
    file:write("discovery targets emitted: ", tostring(metrics.discovery_emitted_targets), "\n")
    file:write("discovery targets suppressed: ", tostring(metrics.discovery_suppressed_targets), "\n")
    file:write("discovery console emissions: ", tostring(metrics.discovery_emitted_count), "\n")
    file:write("discovery already-emitted occurrences: ",
        tostring(metrics.discovery_already_emitted_count), "\n")
    file:write("discovery suppressed occurrences: ",
        tostring(metrics.discovery_suppressed_count), "\n")
    file:write("dynamic calls: ", tostring(metrics.dynamic_calls), "\n")
    file:write("GNAME dispatches: ", tostring(metrics.gname_dispatches), "\n")
    file:write(">R word dispatches: ",
        tostring(metrics.return_data_push_words), "\n")
    file:write("R> word dispatches: ",
        tostring(metrics.return_data_pop_words), "\n")
    file:write("return-data pushes: ", tostring(metrics.return_data_pushes), "\n")
    file:write("return-data pops: ", tostring(metrics.return_data_pops), "\n")
    file:write("maximum return-data depth: ",
        tostring(metrics.maximum_return_data_depth), "\n")
    file:write("maximum unknown-return depth: ",
        tostring(metrics.maximum_unknown_return_depth), "\n")
    file:write("structural call-frame observations: ",
        tostring(metrics.structural_call_frame_observations), "\n")
    file:write("maximum structural call depth: ",
        tostring(metrics.maximum_structural_call_depth), "\n")
    file:write("repeated full states retained: ", tostring(metrics.repeated_states), "\n")
    file:write("nonlocal unwinds: ", tostring(metrics.nonlocal_unwinds), "\n")

    local last = G.state.last_dispatch
    if last then
        file:write(string.format(
            "last dispatch: IP=$%04X target=$%04X SP=$%04X IX=$%04X IY=$%04X\n",
            last.ip, last.target, last.sp, last.ix, last.iy))
    end

    file:write("\nHOT TARGETS\n")
    local hot = G.core.sorted_counts(G.state.word_counts)
    for index = 1, math.min(SUMMARY_LIMIT, #hot) do
        local row = hot[index]
        file:write(string.format("%8d  $%04X  %s\n",
            row.count, row.address, G.core.label(row.address)))
    end

    file:write("\nNON-EXACT TARGETS\n")
    local unknown = G.core.sorted_counts(G.state.unknown_counts)
    for index = 1, math.min(SUMMARY_LIMIT, #unknown) do
        local row = unknown[index]
        local high_level = G.core.u8_direct(row.address) == 0xCF
        local decoded = G.core.target_decode(row.address, high_level)
        local category = decoded.description and "HYPOTHESIS" or "DISCOVERY"
        file:write(string.format("%8d  $%04X  %-10s  %s\n",
            row.count, row.address, category, G.core.label(row.address)))
    end
    file:close()
end

local function save_test(test)
    G.config.exact_trace = false
    local observed_rows = G.state.total_words
    local rows = chronological_trace()
    local trace_rows = G.save_trace(path(test.id .. ".csv"), TRACE_CAPACITY)
    local diagnostic_rows = save_diagnostic_trace(test, rows)
    local transition_rows = save_transitions(test, rows)
    local discovery_rows = G.save_discovery(path(test.id .. "_non_exact.asm"))
    local emission_rows = G.save_discovery_emissions(
        path(test.id .. "_discovery_emissions.csv"))
    local dropped_rows = math.max(0, observed_rows - trace_rows)
    local metrics = capture_metrics(rows, G.state.discovery_emissions)
    save_summary(test, trace_rows, transition_rows, discovery_rows, emission_rows,
        dropped_rows, metrics)

    manifest_line(string.format(
        "%s: observed=%d trace=%d dropped=%d diagnostic=%d transitions=%d non_exact=%d discovery_targets=%d emitted_targets=%d suppressed_targets=%d console_emissions=%d already_emitted=%d suppressed_occurrences=%d dynamic_calls=%d gname=%d gtR=%d Rgt=%d return_data_pushes=%d return_data_pops=%d max_return_data=%d max_unknown_return=%d structural_frames=%d max_structural_depth=%d repeated_states=%d nonlocal_unwinds=%d",
        test.id, observed_rows, trace_rows, dropped_rows, diagnostic_rows,
        transition_rows, discovery_rows, emission_rows,
        metrics.discovery_emitted_targets, metrics.discovery_suppressed_targets,
        metrics.discovery_emitted_count, metrics.discovery_already_emitted_count,
        metrics.discovery_suppressed_count, metrics.dynamic_calls,
        metrics.gname_dispatches, metrics.return_data_push_words,
        metrics.return_data_pop_words,
        metrics.return_data_pushes, metrics.return_data_pops,
        metrics.maximum_return_data_depth,
        metrics.maximum_unknown_return_depth,
        metrics.structural_call_frame_observations,
        metrics.maximum_structural_call_depth,
        metrics.repeated_states, metrics.nonlocal_unwinds))
    out(string.format(
        "Saved %s: %d/%d trace rows, %d dropped, %d transitions, %d non-exact targets, %d discovery audit rows",
        test.id, trace_rows, observed_rows, dropped_rows, transition_rows,
        discovery_rows, emission_rows))
end

local function restore_monitor()
    G.config.exact_trace = false
    if T.dispatch_wrapper and G.core.on_dispatch == T.dispatch_wrapper then
        G.core.on_dispatch = T.original_on_dispatch
    end
    pcall(G.discovery, T.original.discovery_mode or "unknown")
    G.config.trace_capacity = T.original.trace_capacity
    G.config.exact_trace = T.original.exact_trace
end

local function restore_shortcuts()
    for name, shortcut in pairs(T.shortcuts) do
        if rawget(_G, name) == shortcut.handler then
            rawset(_G, name, shortcut.restore and shortcut.previous or nil)
        end
    end
end

local function show_ready_prompt()
    local test = tests[T.test_index]
    T.phase = "await_start"
    out("")
    out(string.format("TEST %d/%d: %s", T.test_index, #tests, test.title))
    out("MAME is stopped. Enter gtrun() to navigate to the event start; gtpause() stops it again.")
    out(test.ready)
    out("At the exact event start, return to this console and enter gtack().")
    out("gtack() will stop, reset/arm the capture, and resume automatically.")
    out("To bypass tests, use gtskip() for this test or gtskip(N) to skip to test N.")
end

function T.pause(quiet)
    local current_emu = rawget(_G, "emu")
    assert(current_emu and type(current_emu.pause) == "function",
        "MAME Lua emu.pause() is unavailable")

    -- Pause the machine first, then tell the debugger to remain stopped.  This
    -- prevents any later dispatch from entering a capture while it is saved.
    control_call("pause", function() current_emu.pause() end)
    local debugger = debugger_manager()
    if debugger then
        control_call("stop the debugger", function()
            debugger.execution_state = "stop"
        end)
    end
    if not quiet then out("MAME stopped") end
    return "stopped"
end

function T.run(quiet)
    local current_emu = rawget(_G, "emu")
    assert(current_emu and type(current_emu.unpause) == "function",
        "MAME Lua emu.unpause() is unavailable")

    -- Release the debugger before unpausing the machine.  Keeping unpause as
    -- the final operation gives gtack() a clean capture boundary.
    local debugger = debugger_manager()
    if debugger then
        control_call("run the debugger", function()
            debugger.execution_state = "run"
        end)
    end
    control_call("unpause", function() current_emu.unpause() end)
    if not quiet then out("MAME running") end
    return "running"
end

function T.next()
    assert(T.active, "test runner is not active")
    local test = tests[T.test_index]
    if T.phase == "await_start" then
        T.pause(true)
        G.config.exact_trace = false
        G.discovery(test.discovery)
        G.reset_trace()
        G.config.exact_trace = true
        T.phase = "await_end"
        out("Capture armed: " .. test.id)
        out(test.capture)
        out("At the event end, enter gtack(); it will stop MAME before saving.")
        T.run(true)
        return "capture armed"
    end

    if T.phase == "await_end" then
        T.pause(true)
        save_test(test)
        T.test_index = T.test_index + 1
        if T.test_index > #tests then
            T.finish()
            return "test run complete"
        end
        show_ready_prompt()
        return "capture saved"
    end

    error("test runner is not waiting for an acknowledgement")
end

function T.skip(destination)
    assert(T.active, "test runner is not active")
    assert(T.phase == "await_start",
        "cannot skip while a capture is active; end it with gtack() or abort with gtabort()")

    local current = T.test_index
    local target
    if destination == nil then
        target = current + 1
    else
        assert(type(destination) == "number" and destination == math.floor(destination),
            "gtskip(N) requires an integer test number")
        assert(destination >= 1 and destination <= #tests,
            string.format("test number must be between 1 and %d", #tests))
        assert(destination > current,
            string.format("test %d is not after the current test %d", destination, current))
        target = destination
    end

    T.pause(true)
    G.config.exact_trace = false
    for index = current, math.min(target - 1, #tests) do
        local skipped = tests[index]
        T.skipped[#T.skipped + 1] = skipped.id
        manifest_line(string.format("%s: skipped at=%s", skipped.id,
            os.date("%Y-%m-%d %H:%M:%S")))
        out(string.format("Skipped test %d: %s", index, skipped.title))
    end

    T.test_index = target
    if T.test_index > #tests then
        T.finish()
        return "test run complete"
    end
    show_ready_prompt()
    return string.format("ready for test %d", T.test_index)
end

function T.status()
    local test = tests[T.test_index]
    local paused, debugger_state = control_status()
    local text = table.concat({
        "runner version: " .. T.version,
        "runner revision: " .. T.revision,
        "active: " .. tostring(T.active),
        "phase: " .. tostring(T.phase),
        "test: " .. (test and (test.id .. " - " .. test.title) or "complete"),
        "machine paused: " .. paused,
        "debugger state: " .. debugger_state,
        "trace capacity: " .. tostring(TRACE_CAPACITY),
        "skipped tests: " .. (#T.skipped > 0 and table.concat(T.skipped, ", ") or "none"),
        "captured dispatches: " .. tostring(G.state and G.state.total_words or 0),
        "output: " .. tostring(T.output_directory)
    }, "\n")
    out(text)
    return text
end

function T.finish()
    if not T.active then return "already complete" end
    T.pause(true)
    G.config.exact_trace = false
    manifest_line("completed: " .. os.date("%Y-%m-%d %H:%M:%S"))
    T.manifest:close()
    T.manifest = nil
    restore_monitor()
    T.active = false
    T.phase = "complete"
    restore_shortcuts()
    out("Test run complete")
    out("Output directory: " .. T.output_directory)
    out("MAME remains stopped. Use GorfMonitorTest.run() when you are ready to continue.")
    return T.output_directory
end

function T.abort(quiet)
    if not T.active then return "already stopped" end
    T.pause(true)
    G.config.exact_trace = false
    if T.manifest then
        manifest_line("aborted: " .. os.date("%Y-%m-%d %H:%M:%S"))
        T.manifest:close()
        T.manifest = nil
    end
    restore_monitor()
    T.active = false
    T.phase = "aborted"
    restore_shortcuts()
    if not quiet then
        out("Test run aborted; completed files were retained")
        out("Output directory: " .. tostring(T.output_directory))
        out("MAME remains stopped. Use GorfMonitorTest.run() when you are ready to continue.")
    end
    return "aborted"
end

T.gtack = function() return T.next() end
T.gtstatus = function() return T.status() end
T.gtabort = function() return T.abort(false) end
T.gtrun = function() return T.run(false) end
T.gtpause = function() return T.pause(false) end
T.gtskip = function(destination) return T.skip(destination) end

local function install_shortcut(name)
    local previous = rawget(_G, name)
    T.shortcuts[name] = {
        handler = T[name],
        previous = previous,
        restore = previous ~= nil
    }
    rawset(_G, name, T[name])
end

create_output_directory()

T.phase = "setup"
T.pause(true)
G.config.exact_trace = false
G.discovery("off")
G.config.trace_capacity = TRACE_CAPACITY
G.reset_trace()

local loader = rawget(_G, "gtl")
assert(type(loader) == "function", "gtl() is not available")
local lst_result = loader()
assert(type(lst_result) == "table" and (lst_result.loaded or 0) > 0,
    "the LST parser did not load any symbols")
T.lst_result = lst_result

-- The installed dispatch tap resolves C.on_dispatch dynamically. Wrapping it
-- here adds raw stack snapshots to each ordinary monitor event without
-- replacing or reinstalling the monitor's tap.
T.original_on_dispatch = G.core.on_dispatch
T.dispatch_wrapper = function(...)
    local sequence_before = G.state.total_words
    T.original_on_dispatch(...)
    local event = G.state.last_dispatch
    if event and event.sequence ~= sequence_before then
        event.raw_ix_cells = raw_stack_words(event.ix, G.data.address.RSP)
        event.raw_sp_cells = raw_stack_words(event.sp, G.data.address.PSP)
    end
end
G.core.on_dispatch = T.dispatch_wrapper

manifest_line("GORF MONITOR GUIDED TEST RUN")
manifest_line("created: " .. os.date("%Y-%m-%d %H:%M:%S"))
manifest_line("runner version: " .. T.version)
manifest_line("runner revision: " .. T.revision)
manifest_line("monitor: " .. G.revision)
manifest_line("data: " .. tostring(G.module_revisions.data))
manifest_line("core: " .. tostring(G.module_revisions.core))
manifest_line("HUD: " .. tostring(G.module_revisions.hud))
manifest_line(string.format("LST: %d addresses, %d labels, %d confirmed, %d superseded",
    lst_result.loaded or 0, lst_result.aliases or 0,
    lst_result.confirmed or 0, lst_result.superseded or 0))
manifest_line("trace capacity: " .. TRACE_CAPACITY)
manifest_line("raw stack cell limit: " .. RAW_STACK_CELL_LIMIT)
manifest_line("")

_G.GorfMonitorTest = T
install_shortcut("gtack")
install_shortcut("gtstatus")
install_shortcut("gtabort")
install_shortcut("gtrun")
install_shortcut("gtpause")
install_shortcut("gtskip")

out("Guided test runner v" .. T.version .. " loaded; build " .. T.revision)
out("Output directory: " .. T.output_directory)
out("Use gtstatus() for the current instruction, gtskip(N) to skip to test N, or gtabort() to stop the run.")
out("Debugger F5/F11 is not needed; use gtrun(), gtpause(), and gtack().")
show_ready_prompt()

return T
