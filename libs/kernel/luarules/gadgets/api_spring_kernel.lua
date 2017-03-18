VFS.Include(KERNEL_FOLDER .. "kernel_utils.lua")

function gadget:GetInfo()
return {
	name    = "Spring kernel gadget",
	desc    = "Spring kernel gadget executor (synced and unsynced)",
	author  = "gajop",
	date    = "after steam release",
	license = "GNU GPL, v2 or later",
	layer   = -10010,
	enabled = true,
}
end

-- SYNCED
if gadgetHandler:IsSyncedCode() then

function gadget:Initialize()
	-- Only use this in development versions
	if not Game.gameVersion:find("$VERSION") then
		Spring.Log(LOG_SECTION, LOG.NOTICE, "Removing kernel for non-development version.")
	    gadgetHandler:RemoveWidget(self)
		return
	end
end

local function ExecuteLua(args)
	msg = {}
	if args.state == "sluarules" then
		local success, error = ExecuteLuaCommand(args.code)
		if not success then
			table.insert(msg, {error, "error"})
		end
		table.insert(msg, {getEchoOutput(), "output"})
		SendToUnsynced("kernelSendToUnsynced", json.encode(msg))
	elseif args.state == "uluarules" then
		SendToUnsynced("kernelExecuteUnsynced", json.encode(args))
	end
end

function gadget:RecvLuaMsg(msg)
	local msg_table = explode('|', msg)
	if msg_table[1] == "spring_kernel_ex" then
		local success, obj = pcall(json.decode, msg_table[2])
		if not success then
			Spring.Log(LOG_SECTION, LOG.ERROR, "Failed to parse JSON: " .. tostring(msg_table[2]))
			Spring.Log(LOG_SECTION, LOG.ERROR, debug.traceback())
			return
		end
		ExecuteLua(obj)
	end
end

-- UNSYNCED
else

local function UnsyncedToWidget(_, data)
    if Script.LuaUI('SK_RecieveGadgetMessage') then
        Script.LuaUI.SK_RecieveGadgetMessage(data)
    end
end

local function ExecuteInUnsynced(_, data)
	local success, obj = pcall(json.decode, data)
	if not success then
		Spring.Log(LOG_SECTION, LOG.ERROR, "Failed to parse JSON: " .. tostring(data))
		Spring.Log(LOG_SECTION, LOG.ERROR, debug.traceback())
		return
	end

	local success, error = ExecuteLuaCommand(obj.code)
	local msg = {}
	if not success then
		table.insert(msg, {error, "error"})
	end
	table.insert(msg, {getEchoOutput(), "output"})
	UnsyncedToWidget(nil, json.encode(msg))
end

function gadget:Initialize()
	-- Only use this in development versions
	if not Game.gameVersion:find("$VERSION") then
		Spring.Log(LOG_SECTION, LOG.NOTICE, "Removing kernel for non-development version.")
	    gadgetHandler:RemoveWidget(self)
		return
	end

	gadgetHandler:AddSyncAction('kernelExecuteUnsynced', ExecuteInUnsynced)
	gadgetHandler:AddSyncAction('kernelSendToUnsynced', UnsyncedToWidget)
end

end
