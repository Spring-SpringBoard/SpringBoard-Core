-- Shared include (widget & gadget)
VFS.Include("savetable.lua")
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

-- Gadget include
elseif GG then
    SB.Include(Path.Join(SB_DIR, "model/runtime_model/runtime_model.lua"))
end
