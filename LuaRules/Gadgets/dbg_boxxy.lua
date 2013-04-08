--THIS GOES IN YOUR GAME GADGETS FOLDER
function gadget:GetInfo()
  return {
    name      = "Boxxy setup",
    desc      = "experiments with changing hitboxes ingame",
    author    = "knorke, modified by Google Frog (volume type), CarRepairer (UI)",
    date      = "dec 1010",
    license   = "raubkopierer sind verbrecher",
    layer     = 0,
    enabled   = true,
  }
end

local d = 10	--step size for moving/resizing

if (gadgetHandler:IsSyncedCode()) then

local euID = nil
--local boxxy = nil


-- Helper Functions
-- [[
local function table_to_string(data, indent)
    local str = ""

    if(indent == nil) then
        indent = 0
    end
	local indenter = "    "
    -- Check the type
    if(type(data) == "string") then
        str = str .. (indenter):rep(indent) .. data .. "\n"
    elseif(type(data) == "number") then
        str = str .. (indenter):rep(indent) .. data .. "\n"
    elseif(type(data) == "boolean") then
        if(data == true) then
            str = str .. "true"
        else
            str = str .. "false"
        end
    elseif(type(data) == "table") then
        local i, v
        for i, v in pairs(data) do
            -- Check for a table in a table
            if(type(v) == "table") then
                str = str .. (indenter):rep(indent) .. i .. ":\n"
                str = str .. table_to_string(v, indent + 2)
            else
                str = str .. (indenter):rep(indent) .. i .. ": " .. table_to_string(v, 0)
            end
        end
	elseif(type(data) == "function") then
		str = str .. (indenter):rep(indent) .. 'function' .. "\n"
    else
        echo(1, "Error: unknown data type: %s", type(data))
    end

    return str
end
--]]


local function printhitbox (box)
if (box) then
	local scaleX = box[1] or "nil"	local scaleY = box[2] or "nil"	local scaleZ = box[3] or "nil"
	local offsetX =box[4] or "nil"	local offsetY =box[5] or "nil"	local offsetZ =box[6] or "nil"
	local volumeTest = box[8] or "nil"
	local volumeType = "nil"
	if box[7] == 0 or box[7] == 4 then
		volumeType = "ellipsoid"
	elseif box[7] == 1 then
		if box[9] == 0 then
			volumeType = "CylX"
		elseif box[9] == 1 then
			volumeType = "CylY"
		else
			volumeType = "CylZ"
		end
	elseif box[7] == 2 then
		volumeType = "box"
	end
	
	--Spring.Echo ("collision: ");Spring.Echo (table_to_string(box))
	
	Spring.Echo ("collisionVolumeScales		= '" .. scaleX .. " " .. scaleY .. " " .. scaleZ .. "',")
	Spring.Echo ("collisionVolumeOffsets	= '" .. offsetX .. " " .. offsetY .. " " .. offsetZ .. "',")
	Spring.Echo ("collisionVolumeTest	    = " .. volumeTest .. ",")
	Spring.Echo ("collisionVolumeType	    = '" .. volumeType .. "',")
 end
end
  
function gadget:RecvLuaMsg(msg, playerID)
	local pre = "boxxy"
	--if (msg:find(pre,1,true)) then Spring.Echo ("its a loveNtrolls message") end
	--local data = explode( '|', msg:sub(#pre+1) )
	local data = explode( '|', msg )
	if data[1] ~= pre then
		return
	end
	local cmd = data[2]
	
	local key = data[3]
	
	local xtra = data[4]
	
	if cmd == 'sel' and key then
		local unitID = key+0 --convert to int!
		euID = unitID 
		return
	end
	
	if (euID) then
		boxxy = ({Spring.GetUnitCollisionVolumeData (euID)})
		
		d = (xtra == 'x' and 10 or 1)
		
		
		if (key=="8") then boxxy[2]=boxxy[2]+d end
		if (key=="2") then boxxy[2]=boxxy[2]-d end
		if (key=="6") then boxxy[1]=boxxy[1]+d end
		if (key=="4") then boxxy[1]=boxxy[1]-d end
		if (key=="7") then boxxy[3]=boxxy[3]-d end
		if (key=="9") then boxxy[3]=boxxy[3]+d end
		if (key=="W") then boxxy[6]=boxxy[6]-d end
		if (key=="S") then boxxy[6]=boxxy[6]+d end
		if (key=="A") then boxxy[4]=boxxy[4]-d end
		if (key=="D") then boxxy[4]=boxxy[4]+d end
		if (key=="Q") then boxxy[5]=boxxy[5]-d end
		if (key=="E") then boxxy[5]=boxxy[5]+d end
		
		if (key==">") then
			boxxy[1]=boxxy[1]+d
			boxxy[2]=boxxy[2]+d
			boxxy[3]=boxxy[3]+d
		end
		if (key=="<") then
			boxxy[1]=boxxy[1]-d
			boxxy[2]=boxxy[2]-d
			boxxy[3]=boxxy[3]-d
		end
		

		if (key=="1") then 
			if boxxy[7] == 0 then
				boxxy[7] = 1
				boxxy[9] = 0
			elseif boxxy[7] == 1 then
				boxxy[9] = boxxy[9]+1
				if boxxy[9] > 2 then
					boxxy[9] = 2
					boxxy[7] = 2
				end
			elseif boxxy[7] == 2 then
				boxxy[7] = 0
			else 
				boxxy[7] = 2
			end
		end		
		if (key=="3") then 
			if boxxy[7] == 0 then
				boxxy[7] = 2
			elseif boxxy[7] == 1 then
				boxxy[9]=boxxy[9]-1
				if boxxy[9] < 0 then
					boxxy[9] = 0
					boxxy[7] = 0
				end
			elseif boxxy[7] == 2 then
				boxxy[7] = 1
				boxxy[9] = 2
			else 
				boxxy[7] = 2
			end
		end	
		if (key=="0") then
			if boxxy[8] == 1 then boxxy[8] = 0 else boxxy[8] = 1 end
		end
		--Spring.Echo ( 'Sending:: ', unpack(boxxy))
		Spring.SetUnitCollisionVolumeData  (euID, unpack(boxxy))
		printhitbox (boxxy)
	end
--Spring.Echo ("RecvLuaMsg: " .. msg .. " from " .. playerID)
	
end



function gadget:Initialize()
	--Spring.Echo ("BOXXY HERE U MAD?")
end


function explode(div,str)
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

else -- ab hier unsync


end