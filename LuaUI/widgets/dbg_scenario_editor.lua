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
    wasEnabled = Spring.IsCheatingEnabled()
    if not wasEnabled then
        Spring.SendCommands("cheat")
    end
    
    VFS.Include("scen_edit/exports.lua")
    if devMode then
        reloadGadgets() --uncomment for development	
        Spring.SendCommands("globallos")
        if not wasEnabled then
            Spring.SendCommands("cheat")
        end
    end

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
    local metaModelLoader = MetaModelLoader()
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


    SCEN_EDIT.model.teamManager:generateTeams(widget) 
    local commands = {}
    for id, team in pairs(SCEN_EDIT.model.teamManager:getAllTeams()) do
        local cmd = SetTeamColorCommand(id, team.color)
        table.insert(commands, cmd)
    end
    local cmd = CompoundCommand(commands)
    SCEN_EDIT.commandManager:execute(cmd)

    if devMode then
        SCEN_EDIT.view = View()

        local viewAreaManagerListener = ViewAreaManagerListener()
        SCEN_EDIT.model.areaManager:addListener(viewAreaManagerListener)
    end
end

function reloadGadgets()
    Spring.SendCommands("luarules reload")
end

function widget:DrawScreen()
    if SCEN_EDIT.view ~= nil then
        SCEN_EDIT.stateManager:DrawScreen()
        SCEN_EDIT.view:DrawScreen()
    end
end

function widget:DrawWorld()
    SCEN_EDIT.executeDelayedGL()

    if SCEN_EDIT.view ~= nil then
        SCEN_EDIT.stateManager:DrawWorld()
        SCEN_EDIT.view:DrawWorld()
    end
    SCEN_EDIT.displayUtil:Draw()
end

function widget:DrawWorldPreUnit()
    if SCEN_EDIT.view ~= nil then
        SCEN_EDIT.stateManager:DrawWorldPreUnit()
        SCEN_EDIT.view:DrawWorldPreUnit()
    end
end

function widget:MousePress(x, y, button)
    if SCEN_EDIT.view ~= nil then
        return SCEN_EDIT.stateManager:MousePress(x, y, button)
    end
end

function widget:MouseMove(x, y, dx, dy, button)
    if SCEN_EDIT.view ~= nil then
        return SCEN_EDIT.stateManager:MouseMove(x, y, button)
    end
end

function widget:MouseRelease(x, y, button)
    if SCEN_EDIT.view ~= nil then
        return SCEN_EDIT.stateManager:MouseRelease(x, y, button)
    end
end

function widget:MouseWheel(up, value)
    if SCEN_EDIT.view ~= nil then
        return SCEN_EDIT.stateManager:MouseWheel(up, value)
    end
end

function widget:KeyPress(key, mods, isRepeat, label, unicode)
    if SCEN_EDIT.view ~= nil then
        return SCEN_EDIT.stateManager:KeyPress(key, mods, isRepeat, label, unicode)
    end
end

function widget:GameFrame(frameNum)
    if SCEN_EDIT.view ~= nil then
        SCEN_EDIT.stateManager:GameFrame(frameNum)
        SCEN_EDIT.view:GameFrame(frameNum)
    end
    SCEN_EDIT.displayUtil:OnFrame()

    if not hasScenarioFile and SCEN_EDIT.projectDir ~= nil and not self.loaded then
        Spring.Echo("Load project")
        local cmd = LoadCommandWidget(SCEN_EDIT.projectDir, false)
        SCEN_EDIT.commandManager:execute(cmd, true)
        self.loaded = true
    end
end

function widget:Update()
    SCEN_EDIT.executeDelayed()
end
