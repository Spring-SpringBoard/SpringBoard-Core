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

local function tobool(val)
  local t = type(val)
  if (t == 'nil') then
    return false
  elseif (t == 'boolean') then
    return val
  elseif (t == 'number') then
    return (val ~= 0)
  elseif (t == 'string') then
    return ((val ~= '0') and (val ~= 'false'))
  end
  return false
end

--include('LuaRules/Gadgets/api_delay.lua')

local echo = Spring.Echo

if (gadgetHandler:IsSyncedCode()) then

SCEN_EDIT = {}
CMD_RESIZE_X = 30521

local myCustomDesc = {
    name    = "resize-x",
    action  = "resize-x",
    id      = CMD_RESIZE_X,
    type    = CMDTYPE.ICON_MAP, -- or whatever is suitable
    tooltip = "resizes x",
    cursor  = "resize-x",
}

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
	local data = explode( '|', msg)
	
	if data[1] ~= pre then return end
    
    local op = data[2]
    local par1 = data[3]
    local par2 = data[4]
    local par3 = data[5]
    local par4 = data[6]
    local par5 = data[7]
	local par6 = data[8]
	local par7 = data[8]
    
    --TODO: figure proper msg name :)
    if op == 'game' then

    elseif devMode then
        if op == 'sync' then
            --        Spring.Echo("Synced message!")
            local msgParsed = string.sub(msg, #(pre .. "|sync|") + 1)
            compress = false
            if compress then
                msgParsed = VFS.ZlibDecompress(msgParsed)
            end
            local msgTable = loadstring(msgParsed)()
            local msg = Message(msgTable.tag, msgTable.data)
            --        table.echo(msg)
            if msg.tag == 'command' then
                local cmd = SCEN_EDIT.resolveCommand(msg.data)
                GG.Delay.DelayCall(CommandManager.execute, {SCEN_EDIT.commandManager, cmd})
            end
        elseif op == 'startMsgPart' then
            Spring.Echo("Start receiving multi part msg")
            msgPartsSize = tonumber(par1)
        elseif op == "msgPart" then
            local index = tonumber(par1)
            local value = string.sub(msg, #(pre .. "|msgPart|" .. par1 .. "|") + 1)
            msgParts[index] = value
            Spring.Echo("Recieved part: " .. tostring(index) .. "/" .. tostring(msgPartsSize))
            if #msgParts == msgPartsSize then
                Spring.Echo("Recieved all parts")
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

local function AddedUnit(unitID, unitDefID, teamID, builderID)
	SCEN_EDIT.model.unitManager:addUnit(unitID)
    SCEN_EDIT.rtModel:UnitCreated(unitID, unitDefID, teamID, builderID)
    if not SCEN_EDIT.rtModel.hasStarted then
        Spring.GiveOrderToUnit(unitID, CMD.FIRE_STATE, { 0 }, {})
    end
end

local function AddedFeature(featureID, allyTeam)
	SCEN_EDIT.model.featureManager:addFeature(featureID)
end

function gadget:Initialize()
    Spring.RevertHeightMap(0, 0, Game.mapSizeX, Game.mapSizeZ, 1)
    VFS.Include("scen_edit/exports.lua")

    vstruct = require("vstruct")
    gadgetHandler:RegisterCMDID(CMD_RESIZE_X)
    Spring.AssignMouseCursor("resize-x", "cursor-x", true, true)
    Spring.SetCustomCommandDrawData(CMD_RESIZE_X, "resize-x", {1,1,1,0.5}, false)
	
    LCS = loadstring(VFS.LoadFile(SCEN_EDIT_DIR .. "lcs/LCS.lua"))
    LCS = LCS()
	VFS.Include(SCEN_EDIT_DIR .. "util.lua")
    SCEN_EDIT.Include(SCEN_EDIT_DIR .. "observable.lua")
	SCEN_EDIT.Include(SCEN_EDIT_DIR .. "display_util.lua")
	SCEN_EDIT.displayUtil = DisplayUtil(false)

	SCEN_EDIT.Include(SCEN_EDIT_DIR .. "model/model.lua")
    SCEN_EDIT.model = Model()
	SCEN_EDIT.Include(SCEN_EDIT_DIR .. "model/runtime_model/runtime_model.lua")

    if devMode then
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
    end

    SCEN_EDIT.Include(SCEN_EDIT_DIR .. "message/message.lua")
    SCEN_EDIT.Include(SCEN_EDIT_DIR .. "message/message_manager.lua")
    SCEN_EDIT.messageManager = MessageManager()

    SCEN_EDIT.Include(SCEN_EDIT_DIR .. "command/command_manager.lua")
    SCEN_EDIT.commandManager = CommandManager()

	rtModel = RuntimeModel()
	SCEN_EDIT.rtModel = rtModel	
	
	
	local allUnits = Spring.GetAllUnits()
    for i = 1, #allUnits do
        local unitId = allUnits[i]
		local unitDefId = Spring.GetUnitDefID(unitId)
		local unitTeamId = Spring.GetUnitTeam(unitId)
        AddedUnit(unitId, unitDefId, unitTeamId)
    end
	local allFeatures = Spring.GetAllFeatures()
	for i = 1, #allFeatures do
        local feature = {}
        local featureId = allFeatures[i]
        local featureDefId = Spring.GetFeatureDefID(featureId)
        local featureTeamId = Spring.GetFeatureTeam(featureId)
		AddedFeature(featureId, featureTeamId)
    end

    SCEN_EDIT.loadFrame = Spring.GetGameFrame() + 1
end

function gadget:GameFrame(frameNum)
	SCEN_EDIT.rtModel:GameFrame(frameNum)
    if SCEN_EDIT.loadFrame == frameNum then
        if scenarioFile then
            local data = VFS.LoadFile(scenarioFile)
            local mission = loadstring(data)()
            SCEN_EDIT.model:Load(mission)
            SCEN_EDIT.rtModel:LoadMission(mission)

            if not devMode then
                SCEN_EDIT.rtModel:GameStart()
            end
        end
    end

end

function gadget:UnitCreated(unitID, unitDefID, teamID, builderID)
	AddedUnit(unitID, unitDefID, teamID, builderID)
end

function gadget:UnitDestroyed(unitID, unitDefID, teamID, attackerID, attackerDefID, attackerTeamID)
    SCEN_EDIT.rtModel:UnitDestroyed(unitID, unitDefID, teamID, attackerID, attackerDefID, attackerTeamID)
	SCEN_EDIT.model.unitManager:removeUnit(unitID)
end

function gadget:FeatureCreated(featureID, allyTeam)
	AddedFeature(featureID, allyteam)
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

function gadget:Shutdown()
end

end
