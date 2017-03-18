VFS.Include(KERNEL_FOLDER .. "kernel_utils.lua")

function widget:GetInfo()
return {
	name    = "Spring kernel communicator and widget module",
	desc    = "Creates a commlink between Spring kernel and Spring",
	author  = "gajop",
	date    = "after steam release",
	license = "GNU GPL, v2 or later",
	layer   = -10010,
	enabled = true,
}
end

local LOG_SECTION = "kernel"
local CONFIG_FILE = KERNEL_FOLDER .. "kernel-config.json"

local socket = socket

local host, port
local client
local buffer = ""
local commands = {} -- table with possible commands

-- drawing related
local screenTex
local vsx, vsy = 0, 0
local draw_requested = false

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Connectivity and sending

local function SocketConnect(host, port)
	client=socket.tcp()
	client:settimeout(0)
	res, err = client:connect(host, port)
	if not res and not res=="timeout" then
		widgetHandler:RemoveWidget(self)
		Spring.Log(LOG_SECTION, LOG.ERROR, "Error in connecting: " .. err)
		return false
	elseif not res=="timeout" then
		Spring.Log(LOG_SECTION, LOG.NOTICE, "Successfully connected to host.")
	end
	return true
end

local SpringKernel = {}
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Callin Functions

local currentCmd = ""
local function DoGadget(cmd)
	local msg = "spring_kernel_ex|" .. json.encode(cmd)
	Spring.SendLuaRulesMsg(msg)
end

local function ExecuteLua(args)
	local msg = {}
	if args.state == "luaui" or args.state == "luamenu" then
		local success, error = ExecuteLuaCommand(args.code)
		if not success then
			table.insert(msg, {error, "error"})
		end
		table.insert(msg, {getEchoOutput(), "output"})
		SpringKernel.WriteOutput(msg)
	elseif args.state == "sluarules" or args.state == "uluarules" then
		DoGadget(args)
	else
		table.insert(msg, {"Invalid state: " .. tostring(args.state), "error"})
		SpringKernel.WriteOutput(msg)
	end
end

local function ShowScreen()
	draw_requested = true
	-- It will be drawn in the next opengl frame
end

-- Callin from gadgets
local function RecieveGadgetMessage(msg)
	local success, obj = pcall(json.decode, msg)
	if not success then
		Spring.Log(LOG_SECTION, LOG.ERROR, "Failed to parse JSON: " .. tostring(msg))
		Spring.Log(LOG_SECTION, LOG.ERROR, debug.traceback())
		return
	end

	SpringKernel.WriteOutput(obj)
end

commands["execute"] = ExecuteLua
commands["show"] = ShowScreen
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Callout Functions



function SpringKernel.WriteOutput(msg)
	-- NOTICE: The gsub part fixes an issue with incorrectly formatted json
	-- FIXME: this suggests an issue with json.encode and should be fixed in the library
	local encoded = json.encode(msg):gsub("\\'", "")
	Spring.Log(LOG_SECTION, LOG.DEBUG, encoded)
	client:send(encoded .. "\n")
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Widget Interface

-- init
function widget:Initialize()
	-- Only use this in development versions
	if not Game.gameVersion:find("$VERSION") then
		Spring.Log(LOG_SECTION, LOG.NOTICE, "Removing kernel for non-development version.")
	    widgetHandler:RemoveWidget(self)
		return
	end

	local config = json.decode(VFS.LoadFile(CONFIG_FILE))
	host, port = config.host, config.port
	if not port or not host then
		widgetHandler:RemoveWidget(self)
		Spring.Log(LOG_SECTION, LOG.ERROR, "Invalid connection details in " .. tostring(CONFIG_FILE))
		return
	end
	Spring.Log(LOG_SECTION, LOG.NOTICE, "Waiting for connection to " ..
		tostring(host) .. ":" .. tostring(port))
	SocketConnect(host, port)

	widgetHandler:RegisterGlobal("SK_RecieveGadgetMessage", RecieveGadgetMessage)

	WG.SpringKernel = SpringKernel

	widget:ViewResize()
end

-- pocesses raw string line and executes command
local function CommandReceived(command)
	local success, obj = pcall(json.decode, command)
	if not success then
		Spring.Log(LOG_SECTION, LOG.ERROR, "Failed to parse JSON: " .. tostring(command))
		Spring.Log(LOG_SECTION, LOG.ERROR, debug.traceback())
	else
		local cmdName = obj.command
		if not cmdName then
			Spring.Log(LOG_SECTION, LOG.ERROR, "Command name is missing from message: " .. tostring(command))
			return
		end
		local f = commands[cmdName]
		if not f then
			Spring.Log(LOG_SECTION, LOG.ERROR, "No such command found: " .. tostring(cmdName))
			return
		end
		f(obj.data)
	end
end

-- update socket - receive data and split into lines
function widget:Update()
	if client == nil then
		SocketConnect(host, port)
		return
	end
	local readable, writeable, err = socket.select({client}, {client}, 0)
	if err ~= nil then
		--Spring.Log(LOG_SECTION, "error", "SpringKernel error in select", err)
		--Echo("Error in select: " .. err)
	end
	for _, input in ipairs(readable) do
		local s, status, str = input:receive('*a') --try to read all data
		if (status == "timeout" or status == nil) and str ~= nil and str ~= "" then
			_connected = true
			CommandReceived(str)
		elseif status == "closed" and _connected then
			Spring.Log(LOG_SECTION, LOG.NOTICE, "Connection closed")
			input:close()
			client = nil
			_connected = false
			SocketConnect(host, port)
		end
	end
end

local function CleanTextures()
	if screenTex then
		gl.DeleteTexture(screenTex)
		screenTex = nil
	end
end

local function CreateTextures()
	screenTex = gl.CreateTexture(vsx, vsy, {
		-- It means you can draw on the texture ;)
		fbo = true, min_filter = GL.LINEAR, mag_filter = GL.LINEAR,
		wrap_s = GL.CLAMP, wrap_t = GL.CLAMP,
	})
	if screenTex == nil then
		Spring.Log(LOG_SECTION, LOG.ERROR, "Error creating screen texture for vsx: " ..
			tostring(vsx) .. ", vsy: " .. tostring(vsy))
	end
end

local function PerformDraw()
	local imgName = "screen.png"
	if draw_requested then
		if VFS.FileExists(imgName, nil, VFS.RAW) then
		    os.remove(imgName)
		end
		draw_requested = false
		gl.CopyToTexture(screenTex, 0, 0, 0, 0, vsx, vsy)
		--gl.Texture(0, screenTex)
		--gl.TexRect(0, vsy, vsx, 0)
		gl.RenderToTexture(screenTex, gl.SaveImage, 0, 0, vsx, vsy, imgName)
		gl.Texture(0, false)
		SpringKernel.WriteOutput({imgPath = GetWriteDataDir() .. imgName})
	end
end

function widget:ViewResize()
	vsx, vsy = gl.GetViewSizes()
	CleanTextures()
	CreateTextures()
end

-- Adds partial compatibility with spring versions, which don't support "DrawScreenPost", remove this later.
-- This call is removed in widget:Initialize() if DrawScreenPost is present
function widget:DrawScreenEffects(vsx, vsy)
	PerformDraw()
end

function widget:DrawScreenPost(vsx, vsy)
	widgetHandler:RemoveCallIn("DrawScreenEffects")
	PerformDraw()
end

function widget:Shutdown()
	CleanTextures()
end
