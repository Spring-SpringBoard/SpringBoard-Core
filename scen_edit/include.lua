VFS.Include("scen_edit/exports.lua")

local includedFiles = { "scen_edit/exports.lua" }
-- include this file
includedFiles[SB.DIRS.SRC .. "include.lua"] = true

function SB.Include(path, env, mode, force)
    if mode == nil then
        mode = VFS.ZIP
    end
    if not includedFiles[path] or force then
        -- mark it included before it's actually included to prevent circular inclusions
        includedFiles[path] = true
        VFS.Include(path, env, mode)
    end
end
--non recursive file include
function SB.IncludeDir(dirPath, env, mode, force)
    local files = VFS.DirList(dirPath, "*", mode)
    local context = Script.GetName()
    for i = 1, #files do
        local file = files[i]
        -- don't load files ending in _gadget.lua in LuaUI nor _widget.lua in LuaRules
        if file:sub(-string.len(".lua")) == ".lua" and
            (context ~= "LuaRules" or file:sub(-string.len("_widget.lua")) ~= "_widget.lua") and
            (context ~= "LuaUI" or file:sub(-string.len("_gadget.lua")) ~= "_gadget.lua") then

            SB.Include(file, env, mode, force)
        end
    end
end
function SB.ZlibCompress(str)
    return tostring(#str) .. "|" .. VFS.ZlibCompress(str)
end

-- Shared include (widget & gadget)
LCS = loadstring(VFS.LoadFile(LIBS_DIR .. "lcs/LCS.lua"))
LCS = LCS()
SB.Include(SB.DIRS.SRC .. 'util.lua')
SB.Include(LIBS_DIR .. 'savetable.lua')
-- SB.Include(LIBS_DIR .. "utils/luaunit.lua")
SB.IncludeDir(LIBS_DIR .. 'utils')

Log.SetLogSection("SpringBoard")
Log.DebugWithInfo(true)

SB.Include(Path.Join(SB.DIRS.SRC, 'observable.lua'))
SB.Include(Path.Join(SB.DIRS.SRC, 'display_util.lua'))
SB.Include(Path.Join(SB.DIRS.SRC, 'conf/conf.lua'))
SB.Include(Path.Join(SB.DIRS.SRC, 'meta/meta_model.lua'))
SB.Include(Path.Join(SB.DIRS.SRC, 'model/model.lua'))
SB.Include(Path.Join(SB.DIRS.SRC, 'message/message.lua'))
SB.Include(Path.Join(SB.DIRS.SRC, 'message/message_manager.lua'))
SB.Include(Path.Join(SB.DIRS.SRC, 'command/command_manager.lua'))

-- Widget include
if WG then
    if Game.gameName:find("SpringBoard ZK") then
        include("keysym.lua")
    else
        require("keysym.lua")
    end
    SB.Include(Path.Join(SB.DIRS.SRC, 'state/state_manager.lua'))
    SB.Include(Path.Join(SB.DIRS.SRC, 'view/view.lua'))
    SB.Include(Path.Join(SB.DIRS.SRC, 'gfx/graphics.lua'))

-- Gadget include
elseif GG then
    SB.Include(Path.Join(SB.DIRS.SRC, 'model/runtime_model/runtime_model.lua'))
end
