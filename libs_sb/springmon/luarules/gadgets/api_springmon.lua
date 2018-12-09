VFS.Include(SPRINGMON_DIR .. "utils/shared.lua")

if gadgetHandler:IsSyncedCode() then
----------------------------
-- Synced
----------------------------
	function gadget:RecvLuaMsg(msg)
		local event = GetEvent(msg)
		if not event then
			return
		end
		if event == COMM_EVENTS.SYNC_GADGETS then
			for vfsFilePath, _ in pairs(GetAddonPathToName()) do
				SendToUnsynced(COMM_EVENTS.REGISTER_GADGET, vfsFilePath)
			end
		elseif event == COMM_EVENTS.FILE_CHANGED then
			local path = msg:sub(#event + 1)
			ReloadFile(path)
		end
		return true
	end
	function gadget:Initialize()
		LoadAddonList()
	end
----------------------------
-- End: Synced
----------------------------
else
----------------------------
-- Unsynced
----------------------------
	function gadget:Initialize()
		local registerGadgetEvent = COMM_EVENTS.REGISTER_GADGET
		if not Script.LuaUI[registerGadgetEvent] then
			return
		end
		gadgetHandler:AddSyncAction(registerGadgetEvent, function (_, vfsFilePath)
			if not Script.LuaUI[registerGadgetEvent] then
				Spring.Log(LOG_SECTION, LOG.ERROR, "Missing Script.LuaUI." .. tostring(registerGadgetEvent))
				return
			end
			Script.LuaUI[registerGadgetEvent](vfsFilePath)
		end)
		Spring.SendLuaRulesMsg(COMM_EVENTS.SYNC_GADGETS)
	end
	function gadget:Shutdown()
		gadgetHandler:RemoveSyncAction(COMM_EVENTS.REGISTER_GADGET)
	end
----------------------------
-- End: Unsynced
----------------------------
end