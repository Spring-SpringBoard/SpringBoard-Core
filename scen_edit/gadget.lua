if (gadgetHandler:IsSyncedCode()) then

function WidgetCallback(f, params, msgID)
    local result = {f(unpack(params))}
    SendToUnsynced("toWidget", table.show{
        tag = "msg",
        data = {
            result = result,
            msgID = msgID,
        },
    })
end

local msgParts = {}
local msgPartsSize = 0
local __populated = false
local __populatedTeam = false

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
        Log.Notice("Send meta data signal")
    else
        if op == 'sync' then
            local msgParsed = msg:sub(#(pre .. "|" .. op .. "|") + 1)
            if SB.messageManager.compress then
                msgParsed = SB.ZlibDecompress(msgParsed)
            end
            local success, msgTable = pcall(function()
                return assert(loadstring(msgParsed))()
            end)
            if not success then
                Log.Error("Failed to load command (size: " .. #msgParsed .. ": ")
                Log.Error(msgTable)
                Log.Error(msgParsed)
                return
            end
            local msg = Message(msgTable.tag, msgTable.data)
            if msg.tag == 'command' then
                if Spring.GetGameRulesParam("sb_gameMode") ~= "play" or SB.projectDir ~= nil then
                    SB.commandManager:HandleCommandMessage(msg)
                else
                    Log.Warning("Command ignored: ", cmd.className)
                end
            end
        elseif op == 'startMsgPart' then
            msgPartsSize = tonumber(par1)
        elseif op == "msgPart" then
            local index = tonumber(par1)
            local value = msg:sub(#(pre .. "|" .. op .. "|" .. par1 .. "|") + 1)
            msgParts[index] = value
            if #msgParts == msgPartsSize then
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
    --Spring.RevertHeightMap(0, 0, Game.mapSizeX, Game.mapSizeZ, 1)
    VFS.Include("scen_edit/exports.lua")
    LCS = loadstring(VFS.LoadFile(LIBS_DIR .. "lcs/LCS.lua"))
    LCS = LCS()
    VFS.Include(SB_DIR .. "util.lua")
    SB.Include(SB_DIR .. "utils/include.lua")

    SB.displayUtil = DisplayUtil()

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
        Log.Error("Unexpected sb_gameMode value: " ..
            tostring(sb_gameMode) .. ". Defaulting to 0.")
        sb_gameMode = "dev"
    end
    Log.Notice("SpringBoard", "info", "Running SpringBoard in " .. sb_gameMode .. "  gameMode.")
    Spring.SetGameRulesParam("sb_gameMode", sb_gameMode)

    --FIXME: shouldn't be here(?)
    SB.conf = Conf()
    SB.metaModel = MetaModel()

    --TODO: relocate this
    metaModelLoader = MetaModelLoader()
    metaModelLoader:Load()

    SB.model = Model()

    SB.messageManager = MessageManager()
    SB.commandManager = CommandManager()

    rtModel = RuntimeModel()
    SB.rtModel = rtModel

    SB.executeDelayed("Initialize")
    --populate the managers now that the listeners are set
    SB.loadFrame = Spring.GetGameFrame() + 1
end

function Load()
    if __populated then
        return
    end

    SB.model.unitManager:populate()
    SB.model.featureManager:populate()
    __populated = true
    if hasScenarioFile then
        Log.Notice("Loading the scenario file...")
        local heightmapData = VFS.LoadFile("heightmap.data", VFS.MOD)
        local modelData = VFS.LoadFile("model.lua", VFS.MOD)
        local texturePath = "texturemap/texture.png"

        local cmds = { LoadModelCommand(modelData), LoadMapCommand(heightmapData)}
        SB.commandManager:execute(CompoundCommand(cmds))
        SB.commandManager:execute(LoadTextureCommand(texturePath), true)

        if Spring.GetGameRulesParam("sb_gameMode") == "play" then
            StartCommand():execute()
        end
    end

    pcall(function()
        local OnStartEditingSynced = SB.model.game.OnStartEditingSynced
        if OnStartEditingSynced then
            OnStartEditingSynced()
        end
    end)
end

function gadget:GamePreload()
    Load()
end

function gadget:GameFrame(frameNum)
    if __populated and not __populatedTeam then
        SB.model.teamManager:populate()
        __populatedTeam = true
    end

    SB.executeDelayed("GameFrame")
    SB.rtModel:GameFrame(frameNum)

    --wait a bit before populating everything (so luaui is loaded)
    if SB.loadFrame == frameNum then
        Load()
    end
end

function gadget:Update()
    --SB.executeDelayed()
end

function gadget:TeamDied(teamID)
	SB.rtModel:TeamDied(teamID)
end

function gadget:UnitCreated(unitID, unitDefID, teamID, builderID)
    if __populated then
        SB.model.unitManager:addUnit(unitID)
    end
    SB.rtModel:UnitCreated(unitID, unitDefID, teamID, builderID)
    -- FIXME: Remove MCL specific hacks
    if Game.gameShortName == "SE MCL" and (unitDefID == 9 or unitDefID == 49) then
        return
    end
    if not SB.rtModel.hasStarted then
        -- FIXME: hack to prevent units being frozen if startCommand is executed in the same frame
        if Spring.GetGameRulesParam("sb_gameMode") == "play" then
            return
        end
        if not SB_USE_PLAY_PAUSE then
            --Spring.MoveCtrl.Enable(unitID)
            --Spring.GiveOrderToUnit(unitID, CMD.FIRE_STATE, { 0 }, {})
            SB.delay(function()
                Spring.SetUnitHealth(unitID, { paralyze = math.pow(2, 32) })
            end)
        end
    end
end

function gadget:UnitDamaged(unitID, unitDefID, unitTeam, damage, paralyzer, weaponDefID, projectileID, attackerID, attackerDefID, attackerTeam)
	SB.rtModel:UnitDamaged(unitID)
end

function gadget:UnitDestroyed(unitID, ...)
    SB.rtModel:UnitDestroyed(unitID, ...)
    if __populated then
        SB.model.unitManager:removeUnit(unitID)
    end
end

function gadget:UnitFinished(unitID, unitDefID, teamID)
    SB.rtModel:UnitFinished(unitID)
end

function gadget:FeatureCreated(featureID, allyTeam)
    if __populated then
        SB.model.featureManager:addFeature(featureID)
    end
    SB.rtModel:FeatureCreated(featureID, allyTeam)
end

function gadget:FeatureDamaged(featureID, ...)
	SB.rtModel:FeatureDamaged(featureID, ...)
end

function gadget:FeatureDestroyed(featureID, ...)
    SB.rtModel:FeatureDestroyed(featureID, ...)
    if __populated then
        SB.model.featureManager:removeFeature(featureID)
    end
end

--[[
function gadget:AllowWeaponTarget(attackerID, targetID, attackerWeaponNum, attackerWeaponDefID, defaultPriority)
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
