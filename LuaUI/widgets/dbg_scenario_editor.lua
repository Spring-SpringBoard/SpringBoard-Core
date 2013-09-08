-------------------------

function widget:GetInfo()
  return {
    name      = "Scenario Editor",
    desc      = "Mod-independent scenario editor",
    author    = "gajop",
    date      = "in the future",
    license   = "GPL-v2",
    layer     = 1001,
    enabled   = true,
  }
end

include("keysym.h.lua")
VFS.Include("savetable.lua")

SCEN_EDIT = {}
--[[
local function DrawCircle()
    gl.Color(0, 255, 0, 0.2)
    local x, y = gl.GetViewSizes()
    gl.LineWidth(200)
    local parts = 1
    local radius = 200
    local multiplier = radius / parts 
    for i=0, parts do
        gl.DrawGroundCircle(area_x + 500, 50, area_z + 500, radius - i * multiplier, 20)
    end
end
]]--

local function explode(div,str)
  if (div=='') then return false end
  local pos,arr = 0,{}
  -- for each divider found
  for st,sp in function() return string.find(str,div,pos,true) end do
    table.insert(arr,string.sub(str,pos,st-1)) -- Attach chars left of current divider
    pos = sp + 1 -- Jump past current divider
  end
  table.insert(arr,string.sub(str,pos)) -- Attach chars right of last divider
  return arr
end

function RecieveGadgetMessage(msg)
    pre = "scen_edit"
    local data = explode( '|', msg)
    if data[1] ~= pre then return end
    local op = data[2]

--    Spring.Echo(msg)
    if op == 'sync' then
--        Spring.Echo("Widget synced!")
        local msgTable = loadstring(string.sub(msg, #(pre .. "|sync|") + 1))()
        local msg = Message(msgTable.tag, msgTable.data)
--        table.echo(msg)
        if msg.tag == 'command' then
            local cmd = SCEN_EDIT.resolveCommand(msg.data)
            SCEN_EDIT.commandManager:execute(cmd, true)
        end
        return
    end
    local tbl = loadstring(msg)()
    local data = tbl.data
    local tag = tbl.tag

    if tag == "msg" then
        model:InvokeCallback(data.msgId, data.result)
    end
end

function widget:Initialize()
    reloadGadgets() --uncomment for development    
    if not WG.Chili then
        widgetHandler:RemoveWidget(widget)
        return
    end
	
    VFS.Include("scen_edit/exports.lua")
    widgetHandler:RegisterGlobal("RecieveGadgetMessage", RecieveGadgetMessage)
    LCS = loadstring(VFS.LoadFile(LIBS_DIR .. "lcs/LCS.lua"))
    LCS = LCS()
    
    VFS.Include(SCEN_EDIT_DIR .. "util.lua")
    SCEN_EDIT.Include(SCEN_EDIT_DIR .. "observable.lua")

    SCEN_EDIT.Include(SCEN_EDIT_DIR .. "display_util.lua")
    SCEN_EDIT.displayUtil = DisplayUtil(true)

    SCEN_EDIT.Include(SCEN_EDIT_DIR .. "conf/conf.lua")
    SCEN_EDIT.conf = Conf()
    
    SCEN_EDIT.Include(SCEN_EDIT_DIR .. "meta/meta_model.lua")
    SCEN_EDIT.metaModel = MetaModel()
    
    --TODO: relocate this
    metaModelLoader = MetaModelLoader()
    metaModelLoader:Load()

    SCEN_EDIT.Include(SCEN_EDIT_DIR .. "model/model.lua")
    SCEN_EDIT.model = Model()

    SCEN_EDIT.model.areaManager = AreaManager()
    SCEN_EDIT.model.unitManager = UnitManager(true)
    SCEN_EDIT.model.featureManager = FeatureManager(true)
    SCEN_EDIT.model.variableManager = VariableManager(true)
    SCEN_EDIT.model.triggerManager = TriggerManager(true)

    SCEN_EDIT.Include(SCEN_EDIT_DIR .. "command/command_manager.lua")
    SCEN_EDIT.commandManager = CommandManager()
    SCEN_EDIT.commandManager.widget = true

    SCEN_EDIT.Include(SCEN_EDIT_DIR .. "state/state_manager.lua")
    SCEN_EDIT.stateManager = StateManager()

    SCEN_EDIT.Include(SCEN_EDIT_DIR .. "view/view.lua")

    SCEN_EDIT.Include(SCEN_EDIT_DIR .. "message/message.lua")
    SCEN_EDIT.Include(SCEN_EDIT_DIR .. "message/message_manager.lua")
    SCEN_EDIT.messageManager = MessageManager()
    SCEN_EDIT.messageManager.widget = true


    --]]
    --    Spring.AssignMouseCursor('cursor-y', 'cursor-y');
    --    Spring.AssignMouseCursor('cursor-x-y-1', 'cursor-x-y-1');
    --    Spring.AssignMouseCursor('cursor-x-y-2', 'cursor-x-y-2');
    --    Spring.AssignMouseCursor('cursor-x', 'cursor-x');
    SCEN_EDIT.model:GenerateTeams(widget) 
    local commands = {}
    for id, team in pairs(SCEN_EDIT.model.teams) do
        local cmd = SetTeamColorCommand(id, team.color)
        table.insert(commands, cmd)
    end
    local cmd = CompoundCommand(commands)
    SCEN_EDIT.commandManager:execute(cmd)

--    gadgetHandler:RegisterCMDID(CMD_RESIZE_X)
--    Spring.SetCustomCommandDrawData(CMD_RESIZE_X, "resizegrip", {1,1,1,0.5}, false)

    if devMode then
        SCEN_EDIT.view = View()

        local viewAreaManagerListener = ViewAreaManagerListener()
        SCEN_EDIT.model.areaManager:addListener(viewAreaManagerListener)
    end
end

function reloadGadgets()
    wasEnabled = Spring.IsCheatingEnabled()
    if not wasEnabled then
        Spring.SendCommands("cheat")
    end
    Spring.SendCommands("luarules reload")
    Spring.SendCommands("globallos")
    if not wasEnabled then
        Spring.SendCommands("cheat")
    end
end

function widget:DrawScreen()
    SCEN_EDIT.stateManager:DrawScreen()
end

function widget:DrawWorld()
    SCEN_EDIT.executeDelayed()
    --has to be initialized here since it creates textures
    if not SCEN_EDIT.model.tm then
        SCEN_EDIT.model.tm = TextureManager()
        SCEN_EDIT.model.tm:generateMapTextures()
    end

    SCEN_EDIT.stateManager:DrawWorld()
    SCEN_EDIT.view:DrawWorld()
    SCEN_EDIT.displayUtil:Draw()
end

function widget:DrawWorldPreUnit()
    SCEN_EDIT.stateManager:DrawWorldPreUnit()
    SCEN_EDIT.view:DrawWorldPreUnit()
end

function widget:MousePress(x, y, button)
    return SCEN_EDIT.stateManager:MousePress(x, y, button)
end

function widget:MouseMove(x, y, dx, dy, button)
    return SCEN_EDIT.stateManager:MouseMove(x, y, button)
end

function widget:MouseRelease(x, y, button)
    return SCEN_EDIT.stateManager:MouseRelease(x, y, button)
end

function widget:MouseWheel(up, value)
    return SCEN_EDIT.stateManager:MouseWheel(up, value)
end

function widget:KeyPress(key, mods, isRepeat, label, unicode)
    return SCEN_EDIT.stateManager:KeyPress(key, mods, isRepeat, label, unicode)
end

function widget:GameFrame(frameNum)
    SCEN_EDIT.stateManager:GameFrame(frameNum)
    SCEN_EDIT.displayUtil:OnFrame()
    SCEN_EDIT.view:GameFrame(frameNum)
end
