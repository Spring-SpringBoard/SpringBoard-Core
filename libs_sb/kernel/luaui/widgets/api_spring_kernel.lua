VFS.Include(KERNEL_FOLDER .. "kernel_utils.lua")

function widget:GetInfo()
	return {
		name    = "Spring kernel communicator and widget module",
		desc    = "Creates a commlink between Spring kernel and Spring",
		author  = "gajop",
		date    = "after steam release",
		license = "MIT",
		layer   = -10010,
		enabled = true,
	}
end

__SK.CONFIG_FILE = KERNEL_FOLDER .. "kernel-config.json"

__SK.socket = socket

__SK.host, __SK.port = nil, nil
__SK.client = nil
__SK.buffer = ""
__SK.commands = {} -- table with possible commands
__SK.isConnected = false

-- drawing related
__SK.screenTex = nil
__SK.vsx, __SK.vsy = 0, 0
__SK.draw_requested = false

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Connectivity and sending

function __SK.SocketConnect(host, port)
	__SK.client=socket.tcp()
	__SK.client:settimeout(0)
	res, err = __SK.client:connect(host, port)
	if not res and not res=="timeout" then
		widgetHandler:RemoveWidget(self)
		Spring.Log(__SK.LOG_SECTION, LOG.ERROR, "Error in connecting: " .. err)
		return false
	elseif not res=="timeout" then
		Spring.Log(__SK.LOG_SECTION, LOG.NOTICE, "Successfully connected to host.")
	end
	return true
end

__SK.SpringKernel = {}
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Callin Functions

function __SK.DoGadget(cmd)
	local msg = "spring_kernel_ex|" .. __SK.json.encode(cmd)
	Spring.SendLuaRulesMsg(msg)
end

function __SK.AutocompleteGadget(cmd)
	local msg = "spring_kernel_autocomplete|" .. __SK.json.encode(cmd)
	Spring.SendLuaRulesMsg(msg)
end

function __SK.ExecuteLua(args)
	local msg = {}
	if args.state == "luaui" or args.state == "luamenu" then
		local success, error = __SK.ExecuteLuaCommand(args.code)
		if not success then
			table.insert(msg, {error, "error"})
		end
		table.insert(msg, {__SK.getEchoOutput(), "output"})
		__SK.SpringKernel.WriteOutput(msg)
	elseif args.state == "sluarules" or args.state == "uluarules" then
		__SK.DoGadget(args)
	else
		table.insert(msg, {"Invalid state: " .. tostring(args.state), "error"})
		__SK.SpringKernel.WriteOutput(msg)
	end
end

function __SK.Autocomplete(args)
	local msg = {}
	if args.state == "luaui" or args.state == "luamenu" then
		local matches = __SK.autocomplete(args.code)
		table.insert(msg, {"matches", matches})
		__SK.SpringKernel.WriteOutput(msg)
	elseif args.state == "sluarules" or args.state == "uluarules" then
		__SK.AutocompleteGadget(args)
	else
		table.insert(msg, {"Invalid state: " .. tostring(args.state), "error"})
		__SK.SpringKernel.WriteOutput(msg)
	end
end

function __SK.ShowScreen()
	__SK.draw_requested = true
	-- It will be drawn in the next opengl frame
end

-- Callin from gadgets
function __SK.RecieveGadgetMessage(msg)
	local success, obj = pcall(__SK.json.decode, msg)
	if not success then
		Spring.Log(__SK.LOG_SECTION, LOG.ERROR, "Failed to parse JSON: " .. tostring(msg))
		Spring.Log(__SK.LOG_SECTION, LOG.ERROR, debug.traceback())
		return
	end

	__SK.SpringKernel.WriteOutput(obj)
end

__SK.commands["execute"] = __SK.ExecuteLua
__SK.commands["autocomplete"] = __SK.Autocomplete
__SK.commands["show"] = __SK.ShowScreen
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Callout Functions



function __SK.SpringKernel.WriteOutput(msg)
	-- NOTICE: The gsub part fixes an issue with incorrectly formatted json
	local encoded = __SK.json.encode(msg)
	if not encoded then
		__SK.client:send("{} \n")
		return
	end
	Spring.Log(__SK.LOG_SECTION, LOG.DEBUG, encoded)
	__SK.client:send(encoded .. "\n")
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Widget Interface

-- init
function widget:Initialize()
	-- Only use this in development versions
	if not Game.gameVersion:find("$VERSION") then
		Spring.Log(__SK.LOG_SECTION, LOG.NOTICE, "Removing kernel for non-development version.")
	    widgetHandler:RemoveWidget(self)
		return
	end

	local config = __SK.json.decode(VFS.LoadFile(__SK.CONFIG_FILE))
	__SK.host, __SK.port = config.host, config.port
	if not __SK.port or not __SK.host then
		widgetHandler:RemoveWidget(self)
		Spring.Log(__SK.LOG_SECTION, LOG.ERROR, "Invalid connection details in " .. tostring(CONFIG_FILE))
		return
	end
	Spring.Log(__SK.LOG_SECTION, LOG.NOTICE, "Waiting for connection to " ..
		tostring(__SK.host) .. ":" .. tostring(__SK.port))
	__SK.SocketConnect(__SK.host, __SK.port)

	widgetHandler:RegisterGlobal("SK_RecieveGadgetMessage", __SK.RecieveGadgetMessage)

	WG.SpringKernel = __SK.SpringKernel

	widget:ViewResize()
end

-- pocesses raw string line and executes command
function __SK.CommandReceived(command)
	local success, obj = pcall(__SK.json.decode, command)
	if not success then
		Spring.Log(__SK.LOG_SECTION, LOG.ERROR, "Failed to parse JSON: " .. tostring(command))
		Spring.Log(__SK.LOG_SECTION, LOG.ERROR, debug.traceback())
	else
		local cmdName = obj.command
		if not cmdName then
			Spring.Log(__SK.LOG_SECTION, LOG.ERROR, "Command name is missing from message: " .. tostring(command))
			return
		end
		local f = __SK.commands[cmdName]
		if not f then
			Spring.Log(__SK.LOG_SECTION, LOG.ERROR, "No such command found: " .. tostring(cmdName))
			return
		end
		f(obj.data)
	end
end

-- update socket - receive data and split into lines
function widget:Update()
	local isConnectedOrig = __SK.isConnected
	__SK.isConnected = false
	if __SK.client then
		if __SK.client:getpeername() then
			__SK.isConnected = true
			if not isConnectedOrig then
				Spring.Log(__SK.LOG_SECTION, LOG.NOTICE, "Connected to " .. __SK.client:getpeername())
			end
		end
	elseif __SK.client == nil then
		__SK.SocketConnect(__SK.host, __SK.port)
		return
	end

	if isConnectedOrig and not __SK.isConnected then
		Spring.Log(__SK.LOG_SECTION, LOG.NOTICE, "Connection closed")
	end

	local readable, writeable, err = __SK.socket.select({__SK.client}, {__SK.client}, 0)
	if err ~= nil then
		--Spring.Log(LOG_SECTION, "error", "SpringKernel error in select", err)
		--Echo("Error in select: " .. err)
	end
	for _, input in ipairs(readable) do
		local s, status, str = input:receive('*a') --try to read all data
		if (status == "timeout" or status == nil) and str ~= nil and str ~= "" then
			__SK.CommandReceived(str)
		elseif status == "closed" then
			input:close()
			__SK.client = nil
		end
	end
end

function __SK.CleanTextures()
	if __SK.screenTex then
		gl.DeleteTexture(__SK.screenTex)
		__SK.screenTex = nil
	end
end

function __SK.CreateTextures()
	__SK.screenTex = gl.CreateTexture(__SK.vsx, __SK.vsy, {
		-- It means you can draw on the texture ;)
		fbo = true, min_filter = GL.LINEAR, mag_filter = GL.LINEAR,
		wrap_s = GL.CLAMP, wrap_t = GL.CLAMP,
	})
	if __SK.screenTex == nil then
		Spring.Log(__SK.LOG_SECTION, LOG.ERROR, "Error creating screen texture for vsx: " ..
			tostring(vsx) .. ", vsy: " .. tostring(vsy))
	end
end

function __SK.PerformDraw()
	local imgName = "screen.png"
	if __SK.draw_requested then
		if VFS.FileExists(imgName, nil, VFS.RAW) then
		    os.remove(imgName)
		end
		__SK.draw_requested = false
		gl.CopyToTexture(__SK.screenTex, 0, 0, 0, 0, __SK.vsx, __SK.vsy)
		--gl.Texture(0, screenTex)
		--gl.TexRect(0, vsy, vsx, 0)
		gl.RenderToTexture(__SK.screenTex, gl.SaveImage, 0, 0, __SK.vsx, __SK.vsy, imgName)
		gl.Texture(0, false)
		__SK.SpringKernel.WriteOutput({imgPath = __SK.GetWriteDataDir() .. imgName})
	end
end

function widget:ViewResize()
	__SK.vsx, __SK.vsy = gl.GetViewSizes()
	__SK.CleanTextures()
	__SK.CreateTextures()
end

-- Adds partial compatibility with spring versions, which don't support "DrawScreenPost", remove this later.
-- This call is removed in widget:Initialize() if DrawScreenPost is present
function widget:DrawScreenEffects(vsx, vsy)
	__SK.PerformDraw()
end

function widget:DrawScreenPost(vsx, vsy)
	widgetHandler:RemoveCallIn("DrawScreenEffects")
	__SK.PerformDraw()
end

function widget:Shutdown()
	__SK.CleanTextures()
end
