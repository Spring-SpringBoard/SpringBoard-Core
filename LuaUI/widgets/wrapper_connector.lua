LIBS_DIRNAME = "libs/"
VFS.Include(LIBS_DIRNAME .. "json.lua")

function widget:GetInfo()
return {
	name    = "Wrapper connector interface",
	desc    = "Creates a commlink between a wrapper program and SB",
	author  = "gajop",
	date    = "before steam release",
	license = "GNU GPL, v2 or later",
	layer   = -10010,
	enabled = true,
}
end

local LOG_SECTION = "connector"
local CONFIG_FILE = "wrapper/connection.json"

local socket = socket

local host, port
local client
local isConnected = false
local buffer = ""
local commands = {} -- table with possible commands

function explode(div,str)
	if div == '' then
		return false
	end
	local pos,arr = 0, {}
	-- for each divider found
	for st,sp in function() return string.find(str,div,pos,true) end do
		table.insert(arr,string.sub(str,pos,st-1)) -- Attach chars left of current divider
		pos = sp + 1 -- Jump past current divider
	end
	table.insert(arr,string.sub(str,pos)) -- Attach chars right of last divider
	return arr
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Connectivity and sending


local function SocketConnect(host, port)
	client=socket.tcp()
	client:settimeout(0)
	res, err = client:connect(host, port)
	if not res and not res=="timeout" then
		widgetHandler:RemoveWidget(self)
		Spring.Log("connector", "error", "Error in connect wrapper: " .. err)
		return false
	end
	return true
end

local Connector = {
	callbacks = {}, -- name based callbacks
}

function Connector.Send(command)
	if not isConnected then
		Spring.Log(LOG_SECTION, LOG.WARNING,
			"No wrapper client detected. Ignoring command: " .. tostring(command.name))
		return
	end
	Spring.Log(LOG_SECTION, "info", "Connector.SendCommand(...)")
	local encoded = json.encode(command)
	client:send(encoded .. "\n")
end

function Connector.Register(name, callback)
	if not Connector.callbacks[name] then
		Connector.callbacks[name] = {}
	end
	table.insert(Connector.callbacks[name], callback)
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Widget Interface

-- init
function widget:Initialize()
	file = VFS.LoadFile(CONFIG_FILE)
	if not file then
		widgetHandler:RemoveWidget(self)
		Spring.Log(LOG_SECTION, "error", "Missing file with connection details " .. tostring(CONFIG_FILE))
		return
	end
	local config = json.decode(file)
	host, port = config.host, config.port
	if not port or not host then
		widgetHandler:RemoveWidget(self)
		Spring.Log(LOG_SECTION, "error", "Invalid connection details in " .. tostring(CONFIG_FILE))
		return
	end
	Spring.Log(LOG_SECTION, "info", "Connecting to " ..
		tostring(host) .. ":" .. tostring(port))
	SocketConnect(host, port)

	WG.Connector = Connector
end

-- pocesses raw string line and executes command
local function CommandReceived(command)
	local success, obj = pcall(json.decode, command)
	if not success then
		Spring.Log(LOG_SECTION, LOG.ERROR, "Failed to parse JSON: " .. tostring(command))
		return
	end

	local name = obj.name
	local params = obj.command

	if not Connector.callbacks[name] then
		Spring.Log(LOG_SECTION, LOG.WARNING, "No callback defined for command: " .. tostring(name))
		return
	end

	for _, callback in pairs(Connector.callbacks[name]) do
		local success, err = pcall(function()
			callback(params)
		end)
		if not success then
			Spring.Log(LOG_SECTION, LOG.ERROR, "Error invoking callback: " .. tostring(err))
			Spring.Log(LOG_SECTION, LOG.ERROR, debug.traceback())
			return
		end
	end
end

-- update socket - receive data and split into lines
function widget:Update()
	isConnected = false
	if client then
		if client:getpeername() then
			isConnected = true
		end
	elseif client == nil then
		SocketConnect(host, port)
		return
	end

	local readable, writeable, err = socket.select({client}, {client}, 0)
	if err ~= nil then
		Spring.Log(LOG_SECTION, "warning", "connector error in select", err)
		--Echo("Error in select: " .. err)
	end
	for _, input in ipairs(readable) do
		local s, status, str = input:receive('*a') --try to read all data
		if (status == "timeout" or status == nil) and str ~= nil and str ~= "" then
			local commandList = explode("\n", str)
			commandList[1] = buffer .. commandList[1]
			for i = 1, #commandList-1 do
				local command = commandList[i]
				if command ~= nil then
					CommandReceived(command)
				end
			end
			buffer = commandList[#commandList]

		elseif status == "closed" then
			input:close()
			client = nil
		end
	end
end
