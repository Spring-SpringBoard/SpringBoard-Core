VFS.Include("scen_edit/exports.lua")

local includedFiles = { "scen_edit/exports.lua" }
-- include this file
includedFiles[SB_DIR .. "include.lua"] = true

function SB.Include(path)
    if not includedFiles[path] then
        -- mark it included before it's actually included to prevent circular inclusions
        includedFiles[path] = true
        VFS.Include(path, nil, VFS.ZIP)
    end
end
--non recursive file include
function SB.IncludeDir(dirPath)
    local files = VFS.DirList(dirPath)
    local context = Script.GetName()
    for i = 1, #files do
        local file = files[i]
        -- don't load files ending in _gadget.lua in LuaUI nor _widget.lua in LuaRules
        if file:sub(-string.len(".lua")) == ".lua" and
            (context ~= "LuaRules" or file:sub(-string.len("_widget.lua")) ~= "_widget.lua") and
            (context ~= "LuaUI" or file:sub(-string.len("_gadget.lua")) ~= "_gadget.lua") then

            SB.Include(file)
        end
    end
end
function SB.ZlibCompress(str)
    return tostring(#str) .. "|" .. VFS.ZlibCompress(str)
end

-- Shared include (widget & gadget)
LCS = loadstring(VFS.LoadFile(LIBS_DIR .. "lcs/LCS.lua"))
LCS = LCS()
SB.Include(SB_DIR .. "util.lua")
SB.Include(LIBS_DIR .. "savetable.lua")
-- SB.Include(LIBS_DIR .. "utils/luaunit.lua")
SB.IncludeDir(LIBS_DIR .. "utils/")

Log.SetLogSection("SpringBoard")
Log.DebugWithInfo(true)

SB.Include(Path.Join(SB_DIR, "observable.lua"))
SB.Include(Path.Join(SB_DIR, "display_util.lua"))
SB.Include(Path.Join(SB_DIR, "conf/conf.lua"))
SB.Include(Path.Join(SB_DIR, "meta/meta_model.lua"))
SB.Include(Path.Join(SB_DIR, "model/model.lua"))
SB.Include(Path.Join(SB_DIR, "message/message.lua"))
SB.Include(Path.Join(SB_DIR, "message/message_manager.lua"))
SB.Include(Path.Join(SB_DIR, "command/command_manager.lua"))

-- Widget include
if WG then
    require("keysym.lua")
    SB.Include(Path.Join(SB_DIR, "state/state_manager.lua"))
    SB.Include(Path.Join(SB_DIR, "view/view.lua"))
    SB.Include(Path.Join(SB_DIR, "gfx/graphics.lua"))

-- Gadget include
elseif GG then
    SB.Include(Path.Join(SB_DIR, "model/runtime_model/runtime_model.lua"))
end
