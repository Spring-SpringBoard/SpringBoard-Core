-- Shared include (widget & gadget)
VFS.Include("savetable.lua")
SB.IncludeDir(SB_DIR .. "utils/")
SB.Include(SB_DIR .. "observable.lua")
SB.Include(SB_DIR .. "display_util.lua")
SB.Include(SB_DIR .. "conf/conf.lua")
SB.Include(SB_DIR .. "meta/meta_model.lua")
SB.Include(SB_DIR .. "model/model.lua")
SB.Include(SB_DIR .. "message/message.lua")
SB.Include(SB_DIR .. "message/message_manager.lua")
SB.Include(SB_DIR .. "command/command_manager.lua")

-- Widget include
if WG then
    include("keysym.h.lua")
    SB.Include(SB_DIR .. "state/state_manager.lua")
    SB.Include(SB_DIR .. "view/view.lua")

-- Gadget include
elseif GG then
    SB.Include(SB_DIR .. "model/runtime_model/runtime_model.lua")
end
