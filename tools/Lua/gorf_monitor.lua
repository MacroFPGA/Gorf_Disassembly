-- gorf_monitor.lua

local source = debug.getinfo(1, "S").source
local directory = source:match("^@(.+[\\/])[^\\/]+$") or "./"
local separator = directory:find("\\", 1, true) and "\\" or "/"
local default_lst = directory .. ".." .. separator .. ".." .. separator
    .. "src" .. separator .. "zout" .. separator .. "Gorf_Disassembly.lst"
local default_test_runner = directory .. "gorf_monitor_test.lua"
local version = "2.3.1"
local revision = "2.3.1-20260812"
local module_api = 1

local modules = {
    data = {
        filename = "gorf_monitor_data.lua",
        name = "data"
    },
    core = {
        filename = "gorf_monitor_core.lua",
        name = "core"
    },
    hud = {
        filename = "gorf_monitor_hud.lua",
        name = "hud"
    }
}

local function load_module(specification)
    local path = directory .. specification.filename
    local module = dofile(path)
    assert(type(module) == "table", path .. " did not return a module table")
    assert(module.module_name == specification.name,
        string.format("unexpected module in %s: got %s; expected %s",
            path, tostring(module.module_name), specification.name))
    assert(module.api_version == module_api,
        string.format("module API mismatch in %s: got %s; expected %d",
            path, tostring(module.api_version), module_api))
    return module
end

-- Stop either public object during the one-time product-name transition.
local stopped = {}
for _, object_name in ipairs({ "GorfMonitor", "GorfTerse" }) do
    local previous = rawget(_G, object_name)
    if previous and previous.stop and not stopped[previous] then
        stopped[previous] = true
        pcall(previous.stop)
    end
end

local G = {
    version = version,
    revision = revision,
    api_version = module_api,
    source = source:gsub("^@", ""),
    config = {
        exact_trace = true,
        discovery_mode = "unknown",
        trace_capacity = 32768,
        hardware_capacity = 256,
        phoneme_capacity = 128,
        utterance_capacity = 32,
        visible = true,
        hud_frozen = false,
        page = "all",
        font_scale = 1,
        hud_refresh_hz = 5,
        auto_place = true,
        region = { x0 = 0.770, y0 = 0.010, x1 = 0.995, y1 = 0.570 }
    }
}

G.data = load_module(modules.data)
local core = load_module(modules.core)
local hud = load_module(modules.hud)
G.module_revisions = {
    data = G.data.revision,
    core = core.revision,
    hud = hud.revision
}

core.attach(G)
hud.attach(G)

local shortcut_pages = {
    gti = "important",
    gtt = "terse",
    gmt = "terse",
    gtg = "game",
    gtau = "audio",
    gtv = "video",
    gta = "all"
}
G.shortcuts = {}
for name, page_name in pairs(shortcut_pages) do
    local selected_page = page_name
    local previous = rawget(_G, name)
    local handler = function() return G.page(selected_page) end
    G.shortcuts[name] = {
        handler = handler,
        previous = previous,
        restore = previous ~= nil
    }
    rawset(_G, name, handler)
end
do
    local previous = rawget(_G, "gtl")
    local handler = function(path)
        return G.load_lst(path or default_lst)
    end
    G.shortcuts.gtl = {
        handler = handler,
        previous = previous,
        restore = previous ~= nil
    }
    rawset(_G, "gtl", handler)
end
do
    local previous = rawget(_G, "gtp")
    local handler = function() return G.next_page() end
    G.shortcuts.gtp = {
        handler = handler,
        previous = previous,
        restore = previous ~= nil
    }
    rawset(_G, "gtp", handler)
end

G.version_info = function()
    local runner = rawget(_G, "GorfMonitorTest")
    local runner_version = "not loaded"
    if runner then
        runner_version = "v" .. tostring(runner.version or "unknown")
            .. ", build " .. tostring(runner.revision or "unknown")
    end
    local text = table.concat({
        "GORF MONITOR VERSIONS",
        "monitor: v" .. G.version .. ", build " .. G.revision,
        "data: " .. tostring(G.module_revisions.data),
        "core: " .. tostring(G.module_revisions.core),
        "HUD: " .. tostring(G.module_revisions.hud),
        "test runner: " .. runner_version
    }, "\n")
    core.print_info(text)
    return text
end

G.load_test = function(path)
    local selected_path = path or default_test_runner
    local ok, result = pcall(dofile, selected_path)
    if not ok then
        error(string.format("cannot load Gorf monitor test runner %s: %s",
            selected_path, tostring(result)), 2)
    end
    G.version_info()
    return result
end
do
    local previous = rawget(_G, "gmts")
    local handler = function(path) return G.load_test(path) end
    G.shortcuts.gmts = {
        handler = handler,
        previous = previous,
        restore = previous ~= nil
    }
    rawset(_G, "gmts", handler)
end
do
    local previous = rawget(_G, "gtversion")
    local handler = function() return G.version_info() end
    G.shortcuts.gtversion = {
        handler = handler,
        previous = previous,
        restore = previous ~= nil
    }
    rawset(_G, "gtversion", handler)
end

G.stop = function()
    if not G.running then return "already stopped" end
    G.running = false
    if G.stop_hud then pcall(G.stop_hud) end
    if G.stop_core then pcall(G.stop_core) end
    for name, shortcut in pairs(G.shortcuts) do
        if rawget(_G, name) == shortcut.handler then
            rawset(_G, name, shortcut.restore and shortcut.previous or nil)
        end
    end
    if rawget(_G, "GorfMonitor") == G then _G.GorfMonitor = nil end
    core.print_info("[GORF MONITOR] stopped")
    return "stopped"
end

G.help = function()
    local text = table.concat({
        "HUD views:",
        "  gti()   important",
        "  gtt()   TERSE",
        "  gmt()   TERSE (legacy shortcut)",
        "  gtg()   game",
        "  gtau()  audio",
        "  gtv()   video",
        "  gta()   all",
        "  gtp()   next view",
        "  gtl()   refresh exact symbols from src/zout/Gorf_Disassembly.lst",
        "  gtl(\"path\") refresh exact symbols from another LST",
        "  gmts()  load gorf_monitor_test.lua",
        "  gmts(\"path\") load another guided test runner",
        "  gtversion() show monitor and module versions",
        "",
        "Full commands:",
        "GorfMonitor.show_important()",
        "GorfMonitor.show_terse()",
        "GorfMonitor.show_game()",
        "GorfMonitor.show_audio()",
        "GorfMonitor.show_video()",
        "GorfMonitor.show_all()",
        "GorfMonitor.page(\"view-name\")",
        "GorfMonitor.next_page()",
        "GorfMonitor.font_scale(1|2|3|4)",
        "GorfMonitor.refresh_rate(1..30)",
        "GorfMonitor.visible(true|false)",
        "GorfMonitor.freeze(true|false)",
        "GorfMonitor.auto_place(true|false)",
        "GorfMonitor.set_region(x0,y0,x1,y1)",
        "GorfMonitor.dump([count])",
        "GorfMonitor.hot([count])",
        "GorfMonitor.unknown([count])",
        "GorfMonitor.save_trace(path[, count])",
        "GorfMonitor.save_discovery(path)",
        "GorfMonitor.save_discovery_emissions(path)",
        "GorfMonitor.load_lst(path)",
        "GorfMonitor.load_test([path])",
        "GorfMonitor.version_info()",
        "GorfMonitor.discovery(\"unknown\"|\"all\"|\"off\")",
        "GorfMonitor.reset_trace()",
        "GorfMonitor.status()",
        "GorfMonitor.stop()"
    }, "\n")
    core.print_info(text)
    return text
end

G.status = function()
    local callback = G.hud and G.hud.callback_style or "none"
    local draws = G.hud and G.hud.draw_count or 0
    local last_error = G.hud and G.hud.last_error or "none"
    local terse = G.get_snapshot().terse
    local text = table.concat({
        "GORF MONITOR " .. G.revision,
        "source: " .. G.source,
        "modules: data " .. tostring(G.module_revisions.data)
            .. ", core " .. tostring(G.module_revisions.core)
            .. ", HUD " .. tostring(G.module_revisions.hud),
        "page: " .. G.config.page,
        "HUD frozen: " .. tostring(G.config.hud_frozen),
        "discovery console: " .. G.config.discovery_mode,
        string.format("IX frames: calls %d, loops %d, data %d, unknown %d",
            terse.reconstructed_call_depth,
            terse.reconstructed_loop_depth,
            terse.reconstructed_return_data_depth,
            terse.reconstructed_unknown_return_depth),
        "HUD callback: " .. callback,
        "HUD draws: " .. tostring(draws),
        "HUD error: " .. tostring(last_error)
    }, "\n")
    core.print_info(text)
    return text
end

_G.GorfMonitor = G
core.print_info("[GORF MONITOR] v" .. G.version .. " loaded; HUD: ALL; build " .. G.revision)
core.print_info("[GORF MONITOR] source: " .. G.source)
G.version_info()
core.print_info(table.concat({
    "[GORF MONITOR] HUD views:",
    "  gti()   important",
    "  gtt()   TERSE",
    "  gmt()   TERSE (legacy shortcut)",
    "  gtg()   game",
    "  gtau()  audio",
    "  gtv()   video",
    "  gta()   all",
    "  gtp()   next view",
    "  gtl()   refresh exact symbols from src/zout/Gorf_Disassembly.lst",
    "  gtl(\"path\") refresh exact symbols from another LST",
    "  gmts()  load gorf_monitor_test.lua",
    "  gtversion() show monitor and module versions",
    "[GORF MONITOR] other commands:",
    "  GorfMonitor.help()"
}, "\n"))

return "GORF monitor loaded"
