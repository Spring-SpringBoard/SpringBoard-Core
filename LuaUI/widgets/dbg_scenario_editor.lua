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
        local msgParsed = string.sub(msg, #(pre .. "|sync|") + 1)
        local msgTable = loadstring(msgParsed)()
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

local function dumpConfig()
    Spring.Log("scened", LOG.NOTICE, "Dump of relevant engine config:")
    local confs = {"HeightMapTexture", "LinkIncomingMaxPacketRate", "LinkIncomingMaxWaitingPackets", "LinkIncomingPeakBandwidth", "LinkIncomingSustainedBandwidth", "LinkOutgoingBandwidth"}
    for _, conf in ipairs(confs) do
        Spring.Log("scened", LOG.NOTICE, conf .. " = " .. Spring.GetConfigString(conf, ""))
    end
end

local function CheckConfig()
    local ok = Spring.GetConfigInt("HeightMapTexture", 0) == 1 and
        Spring.GetConfigInt("LinkIncomingMaxPacketRate", 0) == 64000 and
        Spring.GetConfigInt("LinkIncomingMaxWaitingPackets", 0) == 512000 and
        Spring.GetConfigInt("LinkIncomingPeakBandwidth", 0) == 32768000 and
        Spring.GetConfigInt("LinkIncomingSustainedBandwidth", 0) == 2048000 and
        Spring.GetConfigInt("LinkOutgoingBandwidth", 0) == 65536000

    if not ok then
        local window
        window = Window:New {
            x = "40%",
            y = "35%",
            width = 350,
            height = 250,
            parent = screen0,
            children = {
                Label:New {
                    x = "1%",
                    y = "1%",
                    width = "99%",
                    bottom = "50%",
                    caption = "Scened needs to set correct Engine configuration.",
                },
                Button:New {
                    x = "5%",
                    height = "30%",
                    bottom = "1%",
                    width = 150,
                    caption = "Set config values",
                    OnClick = {
                        function()
                            Spring.SetConfigInt("HeightMapTexture", 1)
                            Spring.SetConfigInt("LinkIncomingMaxPacketRate", 64000)
                            Spring.SetConfigInt("LinkIncomingMaxWaitingPackets", 512000)
                            Spring.SetConfigInt("LinkIncomingPeakBandwidth", 32768000)
                            Spring.SetConfigInt("LinkIncomingSustainedBandwidth", 2048000)
                            Spring.SetConfigInt("LinkOutgoingBandwidth", 65536000)
                            window:Dispose()
                            local restartWindow
                            restartWindow = Window:New {
                                x = "40%",
                                y = "35%",
                                width = 350,
                                height = 250,
                                parent = screen0,
                                children = {
                                    Label:New {
                                        caption = "Spring needs to restart for changes to take effect."
                                    },
                                    Button:New {
                                        caption = "Exit Spring.",
                                        x = "35%",
                                        width = "30%",
                                        height = 80,
                                        y = "51%",
                                        OnClick = {
                                            function()
                                                Spring.SendCommands("quit","quitforce")
                                            end
                                        }
                                    }
                                }
                            }
                        end
                    }
                },
                Button:New {
                    right = "5%",
                    height = "30%",
                    bottom = "1%",
                    width = 150,
                    caption = "Continue without setting",
                    OnClick = {
                        function()
                            window:Dispose()
                        end
                    }
                },
            },
        }
    end
end

local RELOAD_GADGETS = true
function widget:Initialize()
    dumpConfig()

    VFS.Include("scen_edit/exports.lua")

    widgetHandler:RegisterGlobal("RecieveGadgetMessage", RecieveGadgetMessage)
    LCS = loadstring(VFS.LoadFile(LIBS_DIR .. "lcs/LCS.lua"))
    LCS = LCS()

    VFS.Include(SCEN_EDIT_DIR .. "util.lua")

    local wasEnabled = Spring.IsCheatingEnabled()
    if not wasEnabled then
        Spring.SendCommands("cheat")
    end

    -- FIXME: globallos needs to be enabled for terrain loading to be visible
    Spring.SendCommands("globallos")
    if Spring.GetGameRulesParam("sb_gameMode") ~= "play" and RELOAD_GADGETS then
        reloadGadgets() --uncomment for development
    end

    if not wasEnabled then
        Spring.SendCommands("cheat")
    end

    CheckConfig()

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
    cmd.blockUndo = true
    SCEN_EDIT.commandManager:execute(cmd)

    if Spring.GetGameRulesParam("sb_gameMode") ~= "play" then
        Spring.SendCommands('forcestart')
        SCEN_EDIT.view = View()

        local viewAreaManagerListener = ViewAreaManagerListener()
        SCEN_EDIT.model.areaManager:addListener(viewAreaManagerListener)
    end
    self._START_TIME = os.clock()
end

function reloadGadgets()
    Spring.SendCommands("luarules reload")
end

function widget:DrawScreen()
    SCEN_EDIT.executeDelayed("DrawScreen")

    if SCEN_EDIT.view ~= nil then
        SCEN_EDIT.stateManager:DrawScreen()
        SCEN_EDIT.view:DrawScreen()
    end
end

function widget:DrawWorld()
    SCEN_EDIT.executeDelayed("DrawWorld")

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
        return SCEN_EDIT.stateManager:MouseMove(x, y, dx, dy, button)
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

function widget:GamePreload()
    if not hasScenarioFile and SCEN_EDIT.projectDir ~= nil and not SCEN_EDIT.projectLoaded then
        Spring.Log("Scened", LOG.NOTICE, "Loading project (from widget)")
        local cmd = LoadCommandWidget(SCEN_EDIT.projectDir, false)
        SCEN_EDIT.commandManager:execute(cmd, true)
        SCEN_EDIT.projectLoaded = true
    end
end

function widget:GameFrame(frameNum)
    if SCEN_EDIT.view ~= nil then
        SCEN_EDIT.stateManager:GameFrame(frameNum)
    end
    SCEN_EDIT.displayUtil:OnFrame()
end

function widget:Update()
    if self._START_TIME and os.clock() - self._START_TIME >= 1 then
        if not RELOAD_GADGETS then
            SCEN_EDIT.commandManager:execute(ResendCommand())
        end
        self._START_TIME = nil
    end
    if SCEN_EDIT.view ~= nil then
        SCEN_EDIT.stateManager:Update()
        SCEN_EDIT.view:Update()
    end
    SCEN_EDIT.executeDelayed("GameFrame")
    SCEN_EDIT.displayUtil:Update()
end
