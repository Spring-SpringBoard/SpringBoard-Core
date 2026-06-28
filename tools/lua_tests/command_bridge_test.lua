#!/usr/bin/env lua5.1
-- Standalone test of the Lua -> Rust command bridge (no engine).
--
-- Loads the real command_manager.lua + command classes under a mocked
-- Spring.InvokeNativeModule and drives a texture stroke + undo + redo through a
-- simulated gadget, asserting which commands cross to native. Complements the
-- in-engine tests (which feed native directly): this checks the Lua side of the
-- nativeCommandsOnly flip produces the right calls and suppresses the Lua paint.
--
-- Run: lua5.1 tools/lua_tests/command_bridge_test.lua

local ROOT = (arg[0] or ""):match("^(.*)/tools/lua_tests/[^/]*$") or "."

-- ---------------------------------------------------------------------------
-- Mocked engine / framework environment
-- ---------------------------------------------------------------------------

local captured = {}     -- JSON strings passed to Spring.InvokeNativeModule
local sent = {}         -- commands handed to messageManager (cross-state sends)
local delay_gl_calls = 0 -- a non-zero count means a Lua widget GL pass ran
local log_errors = {}

LCS = dofile(ROOT .. "/libs_sb/lcs/LCS.lua")
dofile(ROOT .. "/libs_sb/json.lua") -- defines global `json`

Script = { GetName = function() return "LuaRules" end } -- simulate the gadget

Spring = {
    InvokeNativeModule = function(payload)
        table.insert(captured, payload)
    end,
}

Log = {
    Debug = function() end,
    Notice = function() end,
    Warning = function() end,
    Warn = function() end,
    Error = function(...)
        table.insert(log_errors, table.concat({ ... }, " "))
    end,
}

Table = {
    ShallowCopy = function(t)
        local r = {}
        for k, v in pairs(t) do r[k] = v end
        return r
    end,
}

Path = { Join = function(...) return table.concat({ ... }, "/") end }
VFS = { Include = function() end, LoadFile = function() return "" end, ZIP = 1 }

SB = {
    DIRS = { SRC = ROOT .. "/scen_edit" },
    -- command_manager.lua pulls command files in via SB.Include/IncludeDir; we
    -- preload exactly the classes we need below, so make these no-ops.
    Include = function() end,
    IncludeDir = function() end,
    delayGL = function(_) delay_gl_calls = delay_gl_calls + 1 end,
    messageManager = {
        sendMessage = function(_, msg) table.insert(sent, msg) end,
    },
}

-- ---------------------------------------------------------------------------
-- Real classes under test (load order = dependency order)
-- ---------------------------------------------------------------------------

local function load(rel) dofile(ROOT .. "/scen_edit/" .. rel) end

load("observable.lua")
load("message/message.lua")
load("command/command.lua")
load("command/compound_command.lua")
load("command/undo_command.lua")
load("command/redo_command.lua")
load("command/clear_undo_redo_command.lua")
load("command/set_multiple_command_mode_command.lua")
load("command/widget_command_executed.lua")
load("command/cache_texture_command.lua")
load("command/widget_terrain_change_texture_command.lua")
load("command/terrain_change_texture_command.lua")
load("command/make_shading_texture_command.lua")
load("command/command_manager.lua")

-- ---------------------------------------------------------------------------
-- Test harness
-- ---------------------------------------------------------------------------

local failures = 0
local function check(cond, msg)
    if not cond then
        failures = failures + 1
        io.stderr:write("  FAIL: " .. msg .. "\n")
    end
end

-- Decode each captured payload to its command className (the bridge wraps the
-- command as { tag = "command", data = <serialized command> }).
local function captured_class_names()
    local names = {}
    for _, payload in ipairs(captured) do
        local msg = json.decode(payload)
        names[#names + 1] = msg and msg.data and msg.data.className or "<none>"
    end
    return names
end

-- className of each command handed to the (stubbed) cross-state send. The Lua
-- widget paint command travels this path, so it's how we detect a Lua paint that
-- should have been suppressed.
local function sent_has(class_name)
    for _, msg in ipairs(sent) do
        local data = msg and msg.data
        if data and data.className == class_name then return true end
    end
    return false
end

local function reset()
    captured, sent, delay_gl_calls, log_errors = {}, {}, 0, {}
    SB.commandManager = CommandManager(30, 30)
    SB.commandManager:init(30, 30)
end

local function seq_eq(got, want)
    if #got ~= #want then return false end
    for i = 1, #want do
        if got[i] ~= want[i] then return false end
    end
    return true
end

-- === Test 1: a texture stroke + undo + redo crosses the bridge correctly ===
local function test_texture_stroke_undo_redo()
    reset()
    local cm = SB.commandManager

    -- A stroke as the gadget sees it: enter multi-command mode, two paints,
    -- leave (which merges + closes), then undo, then redo.
    cm:execute(SetMultipleCommandModeCommand(true))
    local opts = { x = 0, z = 0, size = 64, paintMode = "paint" }
    cm:execute(TerrainChangeTextureCommand(opts))
    cm:execute(TerrainChangeTextureCommand(opts))
    cm:execute(SetMultipleCommandModeCommand(false))
    cm:undo()
    cm:redo()

    local got = captured_class_names()
    local want = {
        "SetMultipleCommandModeCommand", -- stream start -> Rust
        "TerrainChangeTextureCommand",   -- paint 1 -> Rust
        "TerrainChangeTextureCommand",   -- paint 2 -> Rust
        "SetMultipleCommandModeCommand", -- stream stop -> Rust
        "TerrainTexturePushStackCommand",-- onMerge stroke close -> Rust
        "UndoCommand",                   -- merged undo routed to Rust
        "RedoCommand",                   -- merged redo routed to Rust
    }
    check(seq_eq(got, want),
        "native call sequence mismatch:\n    got  = { " ..
        table.concat(got, ", ") .. " }\n    want = { " ..
        table.concat(want, ", ") .. " }")

    -- nativeCommandsOnly must suppress the Lua paint: no widget paint command
    -- forwarded, else Lua double-paints every stroke.
    check(not sent_has("WidgetTerrainChangeTextureCommand"),
        "Lua widget paint pass ran (WidgetTerrainChangeTextureCommand forwarded);" ..
        " nativeCommandsOnly should suppress TerrainChangeTextureCommand's Lua execute")
    check(delay_gl_calls == 0,
        "a Lua GL pass ran (" .. delay_gl_calls .. " delayGL calls)")

    -- The paints carry their opts across the bridge.
    local first = json.decode(captured[2])
    check(first and first.data and first.data.opts and first.data.opts.paintMode == "paint",
        "paint command lost its opts crossing the bridge")

    check(#log_errors == 0,
        "command manager logged errors: " .. table.concat(log_errors, " | "))
end

-- === Test 2: CacheTextureCommand is Rust-owned (crosses bridge, no Lua run) ===
local function test_cache_texture_is_native()
    reset()
    SB.commandManager:execute(CacheTextureCommand({ "sometex" }))

    local got = captured_class_names()
    check(seq_eq(got, { "CacheTextureCommand" }),
        "CacheTextureCommand did not reach native exactly once: { " ..
        table.concat(got, ", ") .. " }")
    check(delay_gl_calls == 0,
        "CacheTextureCommand ran the Lua widget cache pass (delayGL)")
end

-- === Test 3: enabling a shading texture reaches Rust ===
local function test_make_shading_texture_is_native()
    reset()
    SB.commandManager:execute(
        MakeShadingTextureCommand({ name = "specular", sizeX = 256, sizeY = 256, color = { 0, 0, 0, 1 } }))

    local got = captured_class_names()
    check(seq_eq(got, { "MakeShadingTextureCommand" }),
        "MakeShadingTextureCommand did not reach native exactly once: { " ..
        table.concat(got, ", ") .. " }")
    local msg = json.decode(captured[1])
    check(msg and msg.data and msg.data.name == "specular" and msg.data.sizeX == 256,
        "MakeShadingTextureCommand lost its fields crossing the bridge")
end

test_texture_stroke_undo_redo()
test_cache_texture_is_native()
test_make_shading_texture_is_native()

if failures == 0 then
    print("command_bridge_test: OK (3 tests)")
    os.exit(0)
else
    io.stderr:write("command_bridge_test: " .. failures .. " failure(s)\n")
    os.exit(1)
end
