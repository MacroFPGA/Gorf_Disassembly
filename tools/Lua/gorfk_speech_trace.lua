-- gorfk_speech_trace.lua

-- Focused Gorf Program-2 speech trace for MAME 0.289.
-- Load from the interactive Lua console enabled with -console:
--   dofile("/absolute/path/gorfk_speech_trace.lua")
--
-- The trace quietly retains commands sent to the SC-01 and reports the
-- resident speech-player state if an active record stops advancing for two
-- seconds. A queued record waiting to start is not reported as a stall.

if GorfKSpeechTrace and GorfKSpeechTrace.stop then
    pcall(GorfKSpeechTrace.stop)
end

local T = {
    version = "2026-08-11.5",
    taps = {},
    subscriptions = {},
    events = {},
    max_events = 256,
    running = false,
    live = false,
    last_command_time = 0,
    last_ready = nil,
    last_ready_time = 0,
    last_stall_signature = nil,
}

local PHONEMES = {
    [0x00]="EH3", [0x01]="EH2", [0x02]="EH1", [0x03]="PA0",
    [0x04]="DT",  [0x05]="pA2", [0x06]="pA1", [0x07]="ZH",
    [0x08]="AH2", [0x09]="I3",  [0x0A]="I2",  [0x0B]="I1",
    [0x0C]="M",   [0x0D]="N",   [0x0E]="pB",  [0x0F]="V",
    [0x10]="CH",  [0x11]="SH",  [0x12]="Z",   [0x13]="AW1",
    [0x14]="NG",  [0x15]="AH1", [0x16]="OO1", [0x17]="OO",
    [0x18]="L",   [0x19]="K0",  [0x1A]="J0",  [0x1B]="H",
    [0x1C]="G",   [0x1D]="pF",  [0x1E]="pD",  [0x1F]="S",
    [0x20]="pA",  [0x21]="AY",  [0x22]="Y1",  [0x23]="UH3",
    [0x24]="AH",  [0x25]="P",   [0x26]="O",   [0x27]="I0",
    [0x28]="U",   [0x29]="Y",   [0x2A]="T",   [0x2B]="R",
    [0x2C]="pE",  [0x2D]="W",   [0x2E]="pAE", [0x2F]="pAE1",
    [0x30]="AW2", [0x31]="UH2", [0x32]="UH1", [0x33]="UH",
    [0x34]="O2",  [0x35]="O1",  [0x36]="IU",  [0x37]="U1",
    [0x38]="THV", [0x39]="TH",  [0x3A]="ER",  [0x3B]="EH",
    [0x3C]="pE1", [0x3D]="AW",  [0x3E]="PA1", [0x3F]="STOP",
}

local function machine()
    local ok, value = pcall(function() return manager.machine end)
    if ok and value then return value end
    ok, value = pcall(function() return manager:machine() end)
    if ok then return value end
    return nil
end

local function info(message)
    local line = "[GORFK SPEECH] " .. message
    if emu and emu.print_info then
        emu.print_info(line)
    else
        print(line)
    end
end

local function now()
    local value = T.machine and T.machine.time
    if value and value.as_double then
        local ok, seconds = pcall(function() return value:as_double() end)
        if ok then return seconds end
    end
    return 0
end

local function state_value(name)
    local entry = T.registers and T.registers[name]
    if not entry then return 0 end
    return entry.value & 0xFFFF
end

local function find_state(cpu, names)
    for _, name in ipairs(names) do
        local entry = cpu.state[name]
        if entry then return entry end
    end
    return nil
end

local function find_space(cpu, preferred, fragment)
    if cpu.spaces[preferred] then return cpu.spaces[preferred] end
    for name, space in pairs(cpu.spaces) do
        local display = (tostring(name) .. " " .. tostring(space.name or "")):lower()
        if display:find(fragment, 1, true) then return space end
    end
    return nil
end

local function read_u8(address)
    local ok, value = pcall(function() return T.program:read_u8(address) end)
    if ok and type(value) == "number" then return value & 0xFF end
    ok, value = pcall(function() return T.program:read_byte(address) end)
    if ok and type(value) == "number" then return value & 0xFF end
    return 0
end

local function read_u16(address)
    return read_u8(address) | (read_u8(address + 1) << 8)
end

local function state_snapshot()
    return {
        count = read_u8(0xD124),
        here = read_u16(0xD122),
        input = read_u16(0xD125),
        output = read_u16(0xD127),
    }
end

local function ready_text()
    if T.last_ready == nil then return "?" end
    return T.last_ready and "1" or "0"
end

local function command_name(raw)
    local name = PHONEMES[raw & 0x3F] or string.format("$%02X", raw & 0x3F)
    if (raw & 0x80) ~= 0 then name = name .. "+HI" end
    if (raw & 0x40) ~= 0 then name = name .. "+UP" end
    return name
end

local function pending_text(speech)
    if speech.count == 0 then return "-" end
    local parts = {}
    local shown = math.min(speech.count, 8)
    for index = 0, shown - 1 do
        local raw = read_u8((speech.here + index) & 0xFFFF)
        parts[#parts + 1] = string.format("$%02X/%s", raw, command_name(raw))
    end
    if speech.count > shown then parts[#parts + 1] = "..." end
    return table.concat(parts, ",")
end

local function ready_age_text()
    if T.last_ready == nil then return "?" end
    return string.format("%.2fs", now() - T.last_ready_time)
end

local function remember(event)
    T.events[#T.events + 1] = event
    if #T.events > T.max_events then table.remove(T.events, 1) end
end

local function trace_command(pc)
    local raw = (state_value("BC") >> 8) & 0xFF
    if (raw & 0x3F) == 0x3F then
        return
    end

    local pointer
    if pc == 0x1150 then
        pointer = (state_value("HL") - 1) & 0xFFFF
    else
        pointer = read_u16(0xD122)
    end
    local speech = state_snapshot()
    local event = {
        time = now(), pc = pc, raw = raw, pointer = pointer,
        count = speech.count, here = speech.here,
        input = speech.input, output = speech.output,
        ready = T.last_ready,
    }
    remember(event)
    T.last_command_time = event.time
    T.last_stall_signature = nil
    if T.live then
        info(string.format(
            "t=%7.3f PC=$%04X raw=$%02X %-8s ptr=$%04X PHONE#=$%02X " ..
            "HERE=$%04X IN=$%04X OUT=$%04X READY=%s",
            event.time, event.pc, event.raw, command_name(event.raw), event.pointer,
            event.count, event.here, event.input, event.output, ready_text()))
    end
end

local function on_io_read(offset, data)
    if not T.running then return data end
    local port = offset & 0xFF
    if port == 0x12 then
        local current = (data & 0x80) ~= 0
        if current ~= T.last_ready then T.last_ready_time = now() end
        T.last_ready = current
    elseif port == 0x17 then
        local pc = state_value("PC")
        if pc == 0x111D or pc == 0x1150 then trace_command(pc) end
    end
    return data
end

local function frame_done()
    if not T.running then return end
    local speech = state_snapshot()
    local active = speech.count ~= 0
    local age = now() - T.last_command_time
    if not active or age < 2.0 then
        if not active then T.last_stall_signature = nil end
        return
    end

    local signature = string.format("%02X:%04X:%04X:%04X:%s",
        speech.count, speech.here, speech.input, speech.output, ready_text())
    if signature == T.last_stall_signature then return end
    T.last_stall_signature = signature
    info(string.format(
        "STALL %.2fs PHONE#=$%02X HERE=$%04X IN=$%04X OUT=$%04X READY=%s " ..
        "READYAGE=%s PC=$%04X NEXT=%s",
        age, speech.count, speech.here, speech.input, speech.output,
        ready_text(), ready_age_text(), state_value("PC"), pending_text(speech)))
end

function T.dump()
    info(string.format("dumping %d retained SC-01 commands", #T.events))
    for index, event in ipairs(T.events) do
        info(string.format(
            "%02d t=%7.3f raw=$%02X %-8s ptr=$%04X PHONE#=$%02X " ..
            "HERE=$%04X IN=$%04X OUT=$%04X",
            index, event.time, event.raw, command_name(event.raw), event.pointer,
            event.count, event.here, event.input, event.output))
    end
    T.stop()
end

function T.status()
    local speech = state_snapshot()
    info(string.format(
        "STATUS PHONE#=$%02X HERE=$%04X IN=$%04X OUT=$%04X READY=%s " ..
        "READYAGE=%s PC=$%04X NEXT=%s",
        speech.count, speech.here, speech.input, speech.output,
        ready_text(), ready_age_text(), state_value("PC"), pending_text(speech)))
end

function T.set_live(enabled)
    T.live = not not enabled
    info("live command output " .. (T.live and "enabled" or "disabled"))
end

local function unsubscribe(subscription)
    if subscription then
        pcall(function() subscription:unsubscribe() end)
    end
end

function T.stop(machine_stopping)
    if not T.running then return end
    T.running = false

    -- Removing a tap changes the address-space handlers.  Unsubscribe the
    -- change notifier first so it cannot reinstall the tap during removal.
    if T.io_notifier then
        unsubscribe(T.io_notifier)
        T.io_notifier = nil
    end

    local taps = T.taps
    T.taps = {}
    for _, tap in pairs(taps) do pcall(function() tap:remove() end) end
    unsubscribe(T.subscriptions.frame)
    T.subscriptions.frame = nil
    if not machine_stopping then
        unsubscribe(T.subscriptions.stop)
    end
    T.subscriptions.stop = nil
    if not machine_stopping then info("stopped") end
end

local m = machine()
if not m then error("MAME machine object is unavailable") end
local cpu = m.devices[":maincpu"] or m.devices[":cpu"]
if not cpu then error("Gorf main CPU was not found") end
local program = find_space(cpu, "program", "program")
local io = find_space(cpu, "io", "io") or find_space(cpu, "i/o", "i/o")
if not program or not io then error("Gorf program or I/O address space was not found") end

T.machine = m
T.cpu = cpu
T.program = program
T.io = io
T.registers = {
    PC = find_state(cpu, { "CURPC", "PC", "pc" }),
    BC = find_state(cpu, { "BC", "bc" }),
    HL = find_state(cpu, { "HL", "hl" }),
}
for _, name in ipairs({ "PC", "BC", "HL" }) do
    if not T.registers[name] then
        error("required Z80 register is unavailable: " .. name)
    end
end
T.last_command_time = now()
T.taps.io_read = io:install_read_tap(
    0, io.address_mask or 0xFFFF, "gorfk_speech_io_read",
    function(offset, data, mask) return on_io_read(offset, data) end)

if io.add_change_notifier then
    T.io_notifier = io:add_change_notifier(function(kind)
        if T.running and (kind == "r" or kind == "rw") and T.taps.io_read then
            T.taps.io_read:reinstall()
        end
    end)
end

if emu and emu.add_machine_frame_notifier then
    T.subscriptions.frame = emu.add_machine_frame_notifier(frame_done)
else
    error("MAME frame callback API is unavailable")
end

if emu and emu.add_machine_stop_notifier then
    T.subscriptions.stop = emu.add_machine_stop_notifier(function()
        T.stop(true)
    end)
end

T.running = true
GorfKSpeechTrace = T
info("loaded v" .. T.version .. " in quiet mode; reproduce the speech problem")
info("then run: GorfKSpeechTrace.status(); GorfKSpeechTrace.dump()")
info("dump() automatically detaches the tracer before MAME exits")

return T
