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

function gadget:RecvLuaMsg(msg, playerID)
	--echo (msg)
	pre = "scenedit"
	--if (msg:find(pre,1,true)) then Spring.Echo ("its a loveNtrolls message") end
	local data = explode( '|', msg)
	
	if data[1] ~= pre then return end
    
    local op = data[2]
    local par1 = data[3]
    local par2 = data[4]
    local par3 = data[5]
    local par4 = data[6]
    local par5 = data[7]

    if op == 'addUnit' then
        if tonumber(par1) ~= nil then
            par1 = tonumber(par1)
        end
        GG.Delay.DelayCall(Spring.CreateUnit, {par1, par2, par3, par4, 0, tonumber(par5)})
    elseif op == "removeUnit" then -- remove a unit (no death animation)
        GG.Delay.DelayCall(Spring.DestroyUnit, {par1, false, true})
    elseif op == "moveUnit" then
        GG.Delay.DelayCall(Spring.SetUnitPosition, {tonumber(par1), par2, par3, par4})
        -- TODO: this is wrong and shouldn't be needed; but it seems that a glitch is causing units to create a move order to their previous position
        GG.Delay.DelayCall(Spring.GiveOrderToUnit, {tonumber(par1), CMD.STOP, {}, {}})
    elseif op == "terr_inc" then
		if tonumber(par3) > 0 then
			GG.Delay.DelayCall(Spring.AddGrass, {par1, par2})
		else
			GG.Delay.DelayCall(Spring.RemoveGrass, {par1, par2})
		end
		GG.Delay.DelayCall(Spring.AdjustHeightMap, {tonumber(par1), tonumber(par2), tonumber(par3)})
	else
		if #op >= #"table" and op:sub(1, #"table") == "table" then
			local tbl = loadstring(op:sub(#"table" + 1))()
			local data = loadstring(tbl.data)()
			local tag = tbl.tag
			
			if tag == "start" then	
				table.echo(data)
				echo("starting mission")
			end
		end
	end
end

function gadget:Initialize()
--    Spring.CreateUnit("armfav", 1000, 30, 1600, 0, 0)
    gadgetHandler:RegisterCMDID(CMD_RESIZE_X)
    Spring.AssignMouseCursor("resize-x", "cursor-x", true, true)
    Spring.SetCustomCommandDrawData(CMD_RESIZE_X, "resize-x", {1,1,1,0.5}, false)
end

else --unsynced

function gadget:Initialize()
end

function gadget:Shutdown()
end
end
