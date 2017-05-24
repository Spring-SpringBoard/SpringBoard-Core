function RecieveGadgetMessage(msg)
    pre = "scen_edit"
    local data = explode( '|', msg)
    if data[1] ~= pre then return end
    local op = data[2]

    if op == 'sync' then
        local msgParsed = string.sub(msg, #(pre .. "|sync|") + 1)
        local msgTable = loadstring(msgParsed)()
        local msg = Message(msgTable.tag, msgTable.data)
        if msg.tag == 'command' then
            local cmd = SB.resolveCommand(msg.data)
            SB.commandManager:execute(cmd, true)
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
    Log.Notice("Dump of relevant engine config:")
    local confs = {"HeightMapTexture", "LinkIncomingMaxPacketRate", "LinkIncomingMaxWaitingPackets", "LinkIncomingPeakBandwidth", "LinkIncomingSustainedBandwidth", "LinkOutgoingBandwidth"}
    for _, conf in ipairs(confs) do
        Log.Notice(conf .. " = " .. Spring.GetConfigString(conf, ""))
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
    VFS.Include("scen_edit/exports.lua")
    LCS = loadstring(VFS.LoadFile(LIBS_DIR .. "lcs/LCS.lua"))
    LCS = LCS()
    VFS.Include(SB_DIR .. "util.lua")
    SB.Include(SB_DIR .. "utils/include.lua")

    dumpConfig()
    widgetHandler:RegisterGlobal("RecieveGadgetMessage", RecieveGadgetMessage)

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

    SB.displayUtil = DisplayUtil(true)

    SB.conf = Conf()
    SB.metaModel = MetaModel()

    --TODO: relocate this
    local metaModelLoader = MetaModelLoader()
    metaModelLoader:Load()

    SB.model = Model()

    SB.model.areaManager = AreaManager()
    SB.model.unitManager = UnitManager(true)
    SB.model.featureManager = FeatureManager(true)
    SB.model.variableManager = VariableManager(true)
    SB.model.triggerManager = TriggerManager(true)
    SB.commandManager = CommandManager()
    SB.commandManager.widget = true
    SB.stateManager = StateManager()
    SB.messageManager = MessageManager()
    SB.messageManager.widget = true


    SB.model.teamManager:generateTeams(widget)
    local commands = {}
    for id, team in pairs(SB.model.teamManager:getAllTeams()) do
        local cmd = SetTeamColorCommand(id, team.color)
        table.insert(commands, cmd)
    end
    local cmd = CompoundCommand(commands)
    cmd.blockUndo = true
    SB.commandManager:execute(cmd)

    if Spring.GetGameRulesParam("sb_gameMode") ~= "play" then
        Spring.SendCommands('forcestart')
        SB.view = View()

        local viewAreaManagerListener = ViewAreaManagerListener()
        SB.model.areaManager:addListener(viewAreaManagerListener)
    end
    self._START_TIME = os.clock()
end

function reloadGadgets()
    Spring.SendCommands("luarules reload")
end

function widget:DrawScreen()
    SB.executeDelayed("DrawScreen")

    if SB.view ~= nil then
        SB.stateManager:DrawScreen()
        SB.view:DrawScreen()
    end
end

function widget:DrawWorld()
    SB.executeDelayed("DrawWorld")

    if SB.view ~= nil then
        SB.stateManager:DrawWorld()
        SB.view:DrawWorld()
    end
    SB.displayUtil:Draw()
end

function widget:DrawWorldPreUnit()
    if SB.view ~= nil then
        SB.stateManager:DrawWorldPreUnit()
        SB.view:DrawWorldPreUnit()
    end
end

function widget:MousePress(x, y, button)
    if SB.view ~= nil then
        return SB.stateManager:MousePress(x, y, button)
    end
end

function widget:MouseMove(x, y, dx, dy, button)
    if SB.view ~= nil then
        return SB.stateManager:MouseMove(x, y, dx, dy, button)
    end
end

function widget:MouseRelease(x, y, button)
    if SB.view ~= nil then
        return SB.stateManager:MouseRelease(x, y, button)
    end
end

function widget:MouseWheel(up, value)
    if SB.view ~= nil then
        return SB.stateManager:MouseWheel(up, value)
    end
end

function widget:KeyPress(key, mods, isRepeat, label, unicode)
    if SB.view ~= nil then
        return SB.stateManager:KeyPress(key, mods, isRepeat, label, unicode)
    end
end

function widget:GamePreload()
    if not hasScenarioFile and SB.projectDir ~= nil and not SB.projectLoaded then
        Log.Notice("Loading project (from widget)")
        local cmd = LoadProjectCommandWidget(SB.projectDir, false)
        SB.commandManager:execute(cmd, true)
        SB.projectLoaded = true
    end
end

function widget:GameFrame(frameNum)
    if SB.view ~= nil then
        SB.stateManager:GameFrame(frameNum)
    end
    SB.displayUtil:OnFrame()
end

function widget:Update()
    if self._START_TIME and os.clock() - self._START_TIME >= 1 then
        if not RELOAD_GADGETS then
            SB.commandManager:execute(ResendCommand())
        end
        self._START_TIME = nil
    end
    if SB.view ~= nil then
        SB.stateManager:Update()
        SB.view:Update()
    end
    SB.executeDelayed("GameFrame")
    SB.displayUtil:Update()
end
