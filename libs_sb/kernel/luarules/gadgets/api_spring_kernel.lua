VFS.Include(KERNEL_FOLDER .. "kernel_utils.lua")

function gadget:GetInfo()
	return {
		name    = "Spring kernel gadget",
		desc    = "Spring kernel gadget executor (synced and unsynced)",
		author  = "gajop",
		license = "MIT",
		layer   = -10010,
		enabled = true,
	}
end

-- SYNCED
if gadgetHandler:IsSyncedCode() then

function gadget:Initialize()
	-- Only use this in development versions
	if not Game.gameVersion:find("$VERSION") then
		Spring.Log(__SK.LOG_SECTION, LOG.NOTICE, "Removing kernel for non-development version.")
	    gadgetHandler:RemoveGadget(self)
		return
	end
end

function __SK.ExecuteLua(args)
	msg = {}
	if args.state == "sluarules" then
		local success, error = __SK.ExecuteLuaCommand(args.code)
		if not success then
			table.insert(msg, {error, "error"})
		end
		table.insert(msg, {__SK.getEchoOutput(), "output"})
		SendToUnsynced("kernelSendToUnsynced", __SK.json.encode(msg))
	elseif args.state == "uluarules" then
		SendToUnsynced("kernelExecuteUnsynced", __SK.json.encode(args))
	end
end

function __SK.Autocomplete(args)
	msg = {}
	if args.state == "sluarules" then
		local matches = __SK.autocomplete(args.code)
		table.insert(msg, {"matches", matches})
		SendToUnsynced("kernelSendToUnsynced", __SK.json.encode(msg))
	elseif args.state == "uluarules" then
		SendToUnsynced("kernelAutocompleteUnsynced", __SK.json.encode(args))
	end
end

function gadget:RecvLuaMsg(msg)
	local msg_table = __SK.explode('|', msg)
	if msg_table[1] == "spring_kernel_ex" then
		local success, obj = pcall(__SK.json.decode, msg_table[2])
		if not success then
			Spring.Log(__SK.LOG_SECTION, LOG.ERROR, "Failed to parse JSON: " .. tostring(msg_table[2]))
			Spring.Log(__SK.LOG_SECTION, LOG.ERROR, debug.traceback())
			return
		end
		__SK.ExecuteLua(obj)
	elseif msg_table[1] == "spring_kernel_autocomplete" then
		local success, obj = pcall(__SK.json.decode, msg_table[2])
		if not success then
			Spring.Log(__SK.LOG_SECTION, LOG.ERROR, "Failed to parse JSON: " .. tostring(msg_table[2]))
			Spring.Log(__SK.LOG_SECTION, LOG.ERROR, debug.traceback())
			return
		end
		__SK.Autocomplete(obj)
	end
end

-- UNSYNCED
else

function __SK.UnsyncedToWidget(_, data)
    if Script.LuaUI('SK_RecieveGadgetMessage') then
        Script.LuaUI.SK_RecieveGadgetMessage(data)
    end
end

function __SK.ExecuteInUnsynced(_, data)
	local success, obj = pcall(__SK.json.decode, data)
	if not success then
		Spring.Log(__SK.LOG_SECTION, LOG.ERROR, "Failed to parse JSON: " .. tostring(data))
		Spring.Log(__SK.LOG_SECTION, LOG.ERROR, debug.traceback())
		return
	end

	local success, error = __SK.ExecuteLuaCommand(obj.code)
	local msg = {}
	if not success then
		table.insert(msg, {error, "error"})
	end
	table.insert(msg, {__SK.getEchoOutput(), "output"})
	__SK.UnsyncedToWidget(nil, __SK.json.encode(msg))
end

function __SK.AutocompleteInUnsynced(_, data)
	local success, obj = pcall(__SK.json.decode, data)
	if not success then
		Spring.Log(__SK.LOG_SECTION, LOG.ERROR, "Failed to parse JSON: " .. tostring(data))
		Spring.Log(__SK.LOG_SECTION, LOG.ERROR, debug.traceback())
		return
	end

	local matches = __SK.autocomplete(args.code)
	table.insert(msg, {"matches", matches})
	local msg = {}
	__SK.UnsyncedToWidget(nil, __SK.json.encode(msg))
end

function gadget:Initialize()
	-- Only use this in development versions
	if not Game.gameVersion:find("$VERSION") then
		Spring.Log(__SK.LOG_SECTION, LOG.NOTICE, "Removing kernel for non-development version.")
	    gadgetHandler:RemoveGadget(self)
		return
	end

	gadgetHandler:AddSyncAction('kernelExecuteUnsynced', __SK.ExecuteInUnsynced)
	gadgetHandler:AddSyncAction('kernelAutocompleteUnsynced', __SK.AutocompleteInUnsynced)
	gadgetHandler:AddSyncAction('kernelSendToUnsynced', __SK.UnsyncedToWidget)
end

end
