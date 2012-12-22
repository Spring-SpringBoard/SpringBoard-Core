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

local devMode = tobool(Spring.GetModOptions().devmode)

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

Spring.SetGameRulesParam('devmode', 1)

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
    elseif op == 'addUnit' then
        if tonumber(par1) ~= nil then
            par1 = tonumber(par1)
        end
		if data[#data - 1] == "callback" then
			GG.Delay.DelayCall(WidgetCallback, {Spring.CreateUnit, {par1, par2, par3, par4, 0, tonumber(par5)}, tonumber(data[#data])})
		else
			GG.Delay.DelayCall(Spring.CreateUnit, {par1, par2, par3, par4, 0, tonumber(par5)})
		end
	elseif op == 'addFeature' then
        if tonumber(par1) ~= nil then
            par1 = tonumber(par1)
        end
		if data[#data - 1] == "callback" then
			GG.Delay.DelayCall(WidgetCallback, {Spring.CreateFeature, {par1, par2, par3, par4, 0, tonumber(par5)}, tonumber(data[#data])})
		else
			GG.Delay.DelayCall(Spring.CreateFeature, {par1, par2, par3, par4, 0, tonumber(par5)})
		end
    elseif op == "removeUnit" then -- remove a unit (no death animation)
        GG.Delay.DelayCall(Spring.DestroyUnit, {par1, false, true})
	elseif op == "removeFeature" then
		GG.Delay.DelayCall(Spring.DestroyFeature, {tonumber(par1)})
    elseif op == "moveUnit" then
        GG.Delay.DelayCall(Spring.SetUnitPosition, {tonumber(par1), par2, par3, par4})
        -- TODO: this is wrong and shouldn't be needed; but it seems that a glitch is causing units to create a move order to their previous position
        GG.Delay.DelayCall(Spring.GiveOrderToUnit, {tonumber(par1), CMD.STOP, {}, {}})
    elseif op == "terr_inc" then
		GG.Delay.DelayCall(Spring.AdjustHeightMap, {par1, par2, par3, par4, tonumber(par5)})
	elseif op == "terr_rev" then
		GG.Delay.DelayCall(Spring.RevertHeightMap, {par1, par2, par3, par4, 1})
	else
		if #op >= #"table" and op:sub(1, #"table") == "table" then
			local tbl = loadstring(op:sub(#"table" + 1))()
			local data = loadstring(tbl.data)()
			local tag = tbl.tag
			
			if tag == "start" then	
				table.echo(data)
				SCEN_EDIT.rtModel:LoadMission(data)
				
				SendToUnsynced("toWidget", table.show{
					tag = "initialized",
					data = "OK",
				})
				SCEN_EDIT.rtModel:GameStart()
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
    VFS.Include("scen_edit/exports.lua")
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

    SCEN_EDIT.Include(SCEN_EDIT_DIR .. "message/message.lua")
    SCEN_EDIT.Include(SCEN_EDIT_DIR .. "message/message_manager.lua")
    SCEN_EDIT.messageManager = MessageManager()

    SCEN_EDIT.Include(SCEN_EDIT_DIR .. "command/command_manager.lua")
    SCEN_EDIT.commandManager = CommandManager()
    SCEN_EDIT.commandManager:loadClasses()

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


    local modOpts = Spring.GetModOptions()
    local scenarioFile = modOpts.scenario_file
    if scenarioFile then
        Spring.Echo("Loading mission...")

	--    local data = VFS.LoadFile(scenarioFile, "r")
    --    SCEN_EDIT.model:Load(data)
--        SCEN_EDIT.rtModel:LoadMission(data)
    end

end

function gadget:GameFrame(frameNum)
	SCEN_EDIT.rtModel:GameFrame(frameNum)
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
--    Spring.RevertHeightMap(0, 0, Game.mapSizeX, Game.mapSizeZ, 1)
end

function gadget:Shutdown()
end

end
