-- Shared include (widget & gadget)
VFS.Include("savetable.lua")
SCEN_EDIT.IncludeDir(SCEN_EDIT_DIR .. "utils/")
SCEN_EDIT.Include(SCEN_EDIT_DIR .. "observable.lua")
SCEN_EDIT.Include(SCEN_EDIT_DIR .. "display_util.lua")
SCEN_EDIT.Include(SCEN_EDIT_DIR .. "conf/conf.lua")
SCEN_EDIT.Include(SCEN_EDIT_DIR .. "meta/meta_model.lua")
SCEN_EDIT.Include(SCEN_EDIT_DIR .. "model/model.lua")
SCEN_EDIT.Include(SCEN_EDIT_DIR .. "message/message.lua")
SCEN_EDIT.Include(SCEN_EDIT_DIR .. "message/message_manager.lua")
SCEN_EDIT.Include(SCEN_EDIT_DIR .. "command/command_manager.lua")

-- Widget include
if WG then
    include("keysym.h.lua")
    SCEN_EDIT.Include(SCEN_EDIT_DIR .. "state/state_manager.lua")
    SCEN_EDIT.Include(SCEN_EDIT_DIR .. "view/view.lua")

-- Gadget include
elseif GG then
    SCEN_EDIT.Include(SCEN_EDIT_DIR .. "model/runtime_model/runtime_model.lua")
end
