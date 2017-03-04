--------------------------
function gadget:GetInfo()
  return {
    name      = "Scenario Editor",
    desc      = "Mod-independent scenario editor",
    author    = "gajop",
    date      = "in the future",
    license   = "GPL-v2",
    layer     = 0,
    enabled   = true,
  }
end


VFS.Include("savetable.lua")

if (gadgetHandler:IsSyncedCode()) then

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

function WidgetCallback(f, params, msgId)
    local result = {f(unpack(params))}
    SendToUnsynced("toWidget", table.show{
        tag = "msg",
        data = {
            result = result,
            msgId = msgId,
        },
    })
end

local msgParts = {}
local msgPartsSize = 0

function gadget:RecvLuaMsg(msg, playerID)
    pre = "scen_edit"
    if #msg < #pre or msg:sub(1, #pre) ~= "scen_edit" then
        return
    end

    local data = explode( '|', msg)
    local op = data[2]
    local par1 = data[3]

    --TODO: figure proper msg name :)
    if op == 'game' then
    elseif op == 'meta' then
        Spring.Echo("Send meta data signal")
    else
        if op == 'sync' then
            local msgParsed = msg:sub(#(pre .. "|" .. op .. "|") + 1)
            if SCEN_EDIT.messageManager.compress then
                msgParsed = SCEN_EDIT.ZlibDecompress(msgParsed)
            end
            local success, msgTable = pcall(function()
                return assert(loadstring(msgParsed))()
            end)
            if not success then
                Spring.Echo("Failed to load command (size: " .. #msgParsed .. ": ")
                Spring.Echo(msgTable)
                return
            end
            local msg = Message(msgTable.tag, msgTable.data)
            if msg.tag == 'command' then
                local cmd = SCEN_EDIT.resolveCommand(msg.data)
                if Spring.GetGameRulesParam("sb_gameMode") ~= "play" or SCEN_EDIT.projectDir ~= nil then
                    GG.Delay.DelayCall(CommandManager.execute, {SCEN_EDIT.commandManager, cmd})
                else
                    Spring.Echo("Command ignored: ", cmd.className)
                end
            end
        elseif op == 'startMsgPart' then
            --Spring.Echo("Start receiving multi part msg")
            msgPartsSize = tonumber(par1)
        elseif op == "msgPart" then
            local index = tonumber(par1)
            local value = msg:sub(#(pre .. "|" .. op .. "|" .. par1 .. "|") + 1)
            msgParts[index] = value
            --Spring.Echo("Recieved part: " .. tostring(index) .. "/" .. tostring(msgPartsSize))
            if #msgParts == msgPartsSize then
                --Spring.Echo("Recieved all parts")
                local fullMessage = ""
                for _, part in pairs(msgParts) do
                    fullMessage = fullMessage .. part
                end
                msgPartsSize = 0
                msgParts = {}

                self:RecvLuaMsg(fullMessage, playerID)
            end
        end
    end
end

function gadget:Initialize()
    -- detect game mode
    local modOpts = Spring.GetModOptions()
    local sb_gameMode = (tonumber(modOpts.sb_gameMode) or 0)
    if sb_gameMode == 0 then
        sb_gameMode = "dev"
    elseif sb_gameMode == 1 then
        sb_gameMode = "test"
    elseif sb_gameMode == 2 then
        sb_gameMode = "play"
    else
        Spring.Log("SpringBoard", "error", "Unexpected sb_gameMode value: " ..
            tostring(sb_gameMode) .. ". Defaulting to 0.")
        sb_gameMode = "dev"
    end
    Spring.Log("SpringBoard", "info", "Running SpringBoard in " .. sb_gameMode .. "  gameMode.")
    Spring.SetGameRulesParam("sb_gameMode", sb_gameMode)

    --Spring.RevertHeightMap(0, 0, Game.mapSizeX, Game.mapSizeZ, 1)
    VFS.Include("scen_edit/exports.lua")

    LCS = loadstring(VFS.LoadFile(LIBS_DIR .. "lcs/LCS.lua"))
    LCS = LCS()
    VFS.Include(SCEN_EDIT_DIR .. "util.lua")
    SCEN_EDIT.Include(SCEN_EDIT_DIR .. "observable.lua")
    SCEN_EDIT.Include(SCEN_EDIT_DIR .. "display_util.lua")
    SCEN_EDIT.displayUtil = DisplayUtil(false)

    --FIXME: shouldn't be here
    SCEN_EDIT.Include(SCEN_EDIT_DIR .. "conf/conf.lua")
    SCEN_EDIT.conf = Conf()

    SCEN_EDIT.Include(SCEN_EDIT_DIR .. "meta/meta_model.lua")
    SCEN_EDIT.metaModel = MetaModel()

    --TODO: relocate this
    metaModelLoader = MetaModelLoader()
    metaModelLoader:Load()

    SCEN_EDIT.Include(SCEN_EDIT_DIR .. "model/model.lua")
    SCEN_EDIT.model = Model()
    SCEN_EDIT.Include(SCEN_EDIT_DIR .. "model/runtime_model/runtime_model.lua")

    SCEN_EDIT.Include(SCEN_EDIT_DIR .. "message/message.lua")
    SCEN_EDIT.Include(SCEN_EDIT_DIR .. "message/message_manager.lua")
    SCEN_EDIT.messageManager = MessageManager()

    SCEN_EDIT.Include(SCEN_EDIT_DIR .. "command/command_manager.lua")
    SCEN_EDIT.commandManager = CommandManager()

    rtModel = RuntimeModel()
    SCEN_EDIT.rtModel = rtModel

    if sb_gameMode ~= "play" then
        local areaManagerListener = AreaManagerListenerGadget()
        SCEN_EDIT.model.areaManager:addListener(areaManagerListener)

        local unitManagerListener = UnitManagerListenerGadget()
        SCEN_EDIT.model.unitManager:addListener(unitManagerListener)

        local featureManagerListener = FeatureManagerListenerGadget()
        SCEN_EDIT.model.featureManager:addListener(featureManagerListener)

        local variableManagerListener = VariableManagerListenerGadget()
        SCEN_EDIT.model.variableManager:addListener(variableManagerListener)

        local triggerManagerListener = TriggerManagerListenerGadget()
        SCEN_EDIT.model.triggerManager:addListener(triggerManagerListener)

        local teamManagerListener = TeamManagerListenerGadget()
        SCEN_EDIT.model.teamManager:addListener(teamManagerListener)

        local scenarioInfoListener = ScenarioInfoListenerGadget()
        SCEN_EDIT.model.scenarioInfo:addListener(scenarioInfoListener)
    end
    --populate the managers now that the listeners are set
    SCEN_EDIT.loadFrame = Spring.GetGameFrame() + 1
end

function Load()
    SCEN_EDIT.model.unitManager:populate()
    SCEN_EDIT.model.featureManager:populate()
    if hasScenarioFile then
        Spring.Log("Scened", LOG.NOTICE, "Loading the scenario file...")
        local heightmapData = VFS.LoadFile("heightmap.data", VFS.MOD)
        local modelData = VFS.LoadFile("model.lua", VFS.MOD)
        local texturePath = "texturemap/texture.png"

        local cmds = { LoadModelCommand(modelData), LoadMap(heightmapData)}
        SCEN_EDIT.commandManager:execute(CompoundCommand(cmds))
        SCEN_EDIT.commandManager:execute(LoadTextureCommand(texturePath), true)

        if Spring.GetGameRulesParam("sb_gameMode") == "play" then
            StartCommand():execute()
        end
    end
end

function gadget:GamePreload()
    Load()
end

function gadget:GameFrame(frameNum)
    SCEN_EDIT.executeDelayed("GameFrame")
    SCEN_EDIT.rtModel:GameFrame(frameNum)

    --wait a bit before populating everything (so luaui is loaded)
    if SCEN_EDIT.loadFrame == frameNum then
        Load()
    end
end

function gadget:Update()
    --SCEN_EDIT.executeDelayed()
end

function gadget:TeamDied(teamID)
	SCEN_EDIT.rtModel:TeamDied(teamID)
end

function gadget:UnitCreated(unitID, unitDefID, teamID, builderID)
    SCEN_EDIT.model.unitManager:addUnit(unitID)
    SCEN_EDIT.rtModel:UnitCreated(unitID, unitDefID, teamID, builderID)
    if Game.gameShortName == "SE MCL" and (unitDefID == 9 or unitDefID == 49) then
        return
    end
    if not SCEN_EDIT.rtModel.hasStarted then
        -- FIXME: hack to prevent units being frozen if startCommand is executed in the same frame
        if Spring.GetGameRulesParam("sb_gameMode") == "play" then
            return
        end
        --Spring.MoveCtrl.Enable(unitID)
        --Spring.GiveOrderToUnit(unitID, CMD.FIRE_STATE, { 0 }, {})
        SCEN_EDIT.delay(function()
            Spring.SetUnitHealth(unitID, { paralyze = math.pow(2, 32) })
        end)
    end
end

function gadget:UnitDamaged(unitID, unitDefID, unitTeam, damage, paralyzer, weaponDefID, projectileID, attackerID, attackerDefID, attackerTeam)
	SCEN_EDIT.rtModel:UnitDamaged(unitID)
end

function gadget:UnitDestroyed(unitID, unitDefID, teamID, attackerID, attackerDefID, attackerTeamID)
    SCEN_EDIT.rtModel:UnitDestroyed(unitID, unitDefID, teamID, attackerID, attackerDefID, attackerTeamID)
    SCEN_EDIT.model.unitManager:removeUnit(unitID)
end

function gadget:UnitFinished(unitID, unitDefID, teamID)
    SCEN_EDIT.rtModel:UnitFinished(unitID)
end

function gadget:FeatureCreated(featureID, allyTeam)
    SCEN_EDIT.model.featureManager:addFeature(featureID)
end

function gadget:FeatureDestroyed(featureID, allyTeam)
    SCEN_EDIT.model.featureManager:removeFeature(featureID)
end

--[[
function gadget:AllowWeaponTarget(attackerID, targetID, attackerWeaponNum, attackerWeaponDefID, defaultPriority)
--    Spring.Echo(attackerID, targetID)
--    return true, 1
--    return false, 1000
end

function gadget:AllowWeaponTargetCheck(attackerID, attackerWeaponNum, attackerWeaponDefID)
--    return true
end
--]]
else --unsynced

local function UnsyncedToWidget(_, data)
    if Script.LuaUI('RecieveGadgetMessage') then
        Script.LuaUI.RecieveGadgetMessage(data)
    end
end

function gadget:Initialize()
    gadgetHandler:AddSyncAction('toWidget', UnsyncedToWidget)
end

end
