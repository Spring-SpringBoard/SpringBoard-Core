-- TODO:
-- Make all WG.SB stuff as a config so there's no direct dependency
-- Save/load user config
-- Make neat UI icons for the controls
-- Better toggle (On/Off) buttons
-- Put it on a repository, load it like other libs
-- Fix fontsize changing on select
-- Pop up on new warning (option)
-- Button to upload log (using the connector)
-- Scrollbar should have a constant height (it can be too small if there's a lot of text)

function widget:GetInfo()
	return {
		name    = 'Developer Console',
		desc    = 'Displays useful information for developers',
		author  = 'Bluestone, gajop, GoogleFrog',
		date    = '2016+',
		license = 'GNU GPL v2',
		layer   = 5000,
		enabled = true
	}
end

local ssub = string.sub
local slen = string.len
local sfind = string.find
local slower = string.lower

local Chili
local screen
local window
local log
local btnFilterProblems
local totalErrors = 0

local COMMAND_NAME = "toggleDevConsole"

-- Config --
local cfg = {
	msgCap      = 50,
	reloadLines = 50000,
	visible = true,
	onlyErrorsAndWarnings = false,
	popupOnError = true,
	popupOnWarning = false, -- not configurable atm
	onlySinceLastReload = true,
}
local fontSize = 16

---------------------

-- Text Colour Config --
local color = {
	oAlly  = '\255\255\128\128', --enemy ally messages (seen only when spectating)
	misc   = '\255\200\200\200', --everything else
	game   = '\255\102\255\255', --server (autohost) chat
	other  = '\255\255\255\255', --normal chat color
	ally   = '\255\001\255\001', --ally chat
	spec   = '\255\255\255\001', --spectator chat
	error  = '\255\255\001\001',
	warning= '\255\255\245\001',
	blue   = '\255\001\255\255',
}

local function SetWindowVisibility(visible)
	cfg.visible = visible
	window:SetVisibility(visible)
end
local function ToggleWindowVisibility()
	SetWindowVisibility(not cfg.visible)
end

local function SetFilterMessages(onlyErrorsAndWarnings)
	cfg.onlyErrorsAndWarnings = onlyErrorsAndWarnings
	ReloadAllMessages()
end
local function ToggleFilterMessages()
	SetFilterMessages(not cfg.onlyErrorsAndWarnings)
end

local function SetPopUpOnError(popupOnError)
	cfg.popupOnError = popupOnError
end
local function TogglePopUpOnError()
	SetPopUpOnError(not cfg.popupOnError)
end

local function SetFilterSinceLastReload(onlySinceLastReload)
	cfg.onlySinceLastReload = onlySinceLastReload
	ReloadAllMessages()
end
local function ToggleFilterSinceLastReload()
	SetFilterSinceLastReload(not cfg.onlySinceLastReload)
end

local function UpdateFilterProblems()
	if totalErrors == 0 then
		btnFilterProblems:SetCaption("Problems(" .. color.blue .. "0\b)")
	else
		btnFilterProblems:SetCaption("Problems(" .. color.error .. tostring(totalErrors) .. "\b)")
	end
end

function loadWindow()
	local wBottom = 0
	local wRight = 0
	local classname
	if WG.SB and WG.SB.conf then
		wBottom = WG.SB.conf.BOTTOM_BAR_HEIGHT
		wRight = WG.SB.conf.RIGHT_PANEL_WIDTH
		classname = 'sb_window'
	end
	-- parent
	window = Chili.Window:New {
		parent    = screen,
		draggable = false,
		resizable = false,
		x = 0,
		right = wRight,
		bottom = wBottom,
		height = 400,
		itemPadding = {5,5,10,10},
		classname = classname,
	}
	-- chat box
	local msgWindow = Chili.ScrollPanel:New {
		verticalSmartScroll = true,
		parent = window,
		x = 0,
		y = 0,
		right = 0,
		height = '82%',
		padding = {0,0,0,0},
		borderColor = {0,0,0,0},
	}
	log = Chili.TextBox:New {
		parent = msgWindow,
		width = '100%',
		padding = {0,0,0,0},
		align = "left",
		valign = "ascender",
		selectable = true,
		autoHeight = true,
		autoObeyLineHeight = true,
		subTooltips = true,
		font = {
			outline = true,
			autoOutlineColor = true,
			outlineWidth = 4,
			outlineWeight = 3,
			size = fontSize,
		}
	}
	local el_size = 8.5
	local curr_x = 0
	local widthStr = ('%f%%'):format(el_size)
	local heightStr = "12%"
	local padding = 0.5

	local btnFontSize = 12

	Chili.Button:New {
		parent = window,
		x = ('%f%%'):format(curr_x),
		bottom = 0,
		width = widthStr,
		height = heightStr,
		caption = "Clear",
		tooltip = "Clear all messages",
		fontSize = btnFontSize,
		OnClick = {
			function()
				RemoveAllMessages()
			end
		}
	}

	curr_x = curr_x + el_size + padding
	btnFilterProblems = Chili.Button:New {
		parent = window,
		x = ('%f%%'):format(curr_x),
		bottom = 0,
		width = widthStr,
		height = heightStr,
		tooltip = "Toggles whether all messages should be displayed, or just warnings and errors.",
		caption = "Problems",
		fontSize = btnFontSize,
		classname = 'toggle_button',
		checked = cfg.onlyErrorsAndWarnings,
		OnClick = {
			function(obj)
				ToggleFilterMessages()
				obj.checked = cfg.onlyErrorsAndWarnings
				obj:Invalidate()
			end
		}
	}
	curr_x = curr_x + el_size + padding
	Chili.Button:New {
		parent = window,
		x = ('%f%%'):format(curr_x),
		bottom = 0,
		width = widthStr,
		height = heightStr,
		tooltip = 'Show messages since the most recent luaui/luarules reload',
		caption = "Current reload",
		fontSize = btnFontSize,
		classname = 'toggle_button',
		checked = cfg.onlySinceLastReload,
		OnClick = {
			function(obj)
				ToggleFilterSinceLastReload()
				obj.checked = cfg.onlySinceLastReload
				obj:Invalidate()
			end
		}
	}
	curr_x = curr_x + el_size + padding
	Chili.Button:New {
		parent = window,
		x = ('%f%%'):format(curr_x),
		bottom = 0,
		width = widthStr,
		height = heightStr,
		caption = "LuaUI Reload",
		fontSize = btnFontSize,
		OnClick = {
			function()
				Spring.SendCommands("luaui reload")
			end
		}
	}
	curr_x = curr_x + el_size + padding
	Chili.Button:New {
		parent = window,
		x = ('%f%%'):format(curr_x),
		bottom = 0,
		width = widthStr,
		height = heightStr,
		caption = "LuaRules Reload",
		fontSize = btnFontSize,
		OnClick = {
			function()
				CheatIfNeeded()
				Spring.SendCommands("luarules reload")
			end
		}
	}
	curr_x = curr_x + el_size + padding
	Chili.Button:New {
		parent = window,
		x = ('%f%%'):format(curr_x),
		bottom = 0,
		width = widthStr,
		height = heightStr,
		caption = "Toggle: Cheat",
		fontSize = btnFontSize,
		OnClick = {
			function()
				Spring.SendCommands("cheat")
			end
		}
	}
	curr_x = curr_x + el_size + padding
	Chili.Button:New {
		parent = window,
		x = ('%f%%'):format(curr_x),
		bottom = 0,
		width = widthStr,
		height = heightStr,
		caption = "Toggle: GlobalLos",
		fontSize = btnFontSize,
		OnClick = {
			function()
				CheatIfNeeded()
				Spring.SendCommands("globallos")
			end
		}
	}
	curr_x = curr_x + el_size + padding
	Chili.Button:New {
		parent = window,
		x = ('%f%%'):format(curr_x),
		bottom = 0,
		width = widthStr,
		height = heightStr,
		caption = "Toggle: GodMode",
		fontSize = btnFontSize,
		OnClick = {
			function()
				CheatIfNeeded()
				Spring.SendCommands("godmode")
			end
		}
	}
	curr_x = curr_x + el_size + padding
	Chili.Button:New {
		parent = window,
		x = ('%f%%'):format(curr_x),
		bottom = 0,
		width = widthStr,
		height = heightStr,
		caption = "Restart",
		fontSize = btnFontSize,
		OnClick = {
			function()
				-- this file is (hopefully) the script.txt used to most recently start spring
				Spring.Reload(VFS.LoadFile("_script.txt"))
			end
		}
	}
	curr_x = curr_x + el_size + padding
	Chili.Button:New {
		parent = window,
		x = ('%f%%'):format(curr_x),
		bottom = 0,
		width = widthStr,
		height = heightStr,
		tooltip = '',
		caption = "Popup on error",
		fontSize = btnFontSize,
		checked = cfg.popupOnError,
		classname = 'toggle_button',
		OnClick = {
			function(obj)
				TogglePopUpOnError()
				obj.checked = cfg.popupOnError
				obj:Invalidate()
			end
		}
	}
	curr_x = curr_x + el_size + padding
	Chili.Button:New {
		parent = window,
		x = ('%f%%'):format(curr_x),
		bottom = 0,
		width = widthStr,
		height = heightStr,
		tooltip = '',
		caption = "Hide/Show (F8)",
		fontSize = btnFontSize,
		OnClick = {
			function()
				ToggleWindowVisibility()
			end
		}
	}
	-- not useful in SB
	if not WG.SB then
		curr_x = curr_x + el_size + padding
		local dbgBtn
		dbgBtn = Chili.Button:New {
			parent = window,
			x = ('%f%%'):format(curr_x),
			bottom = 0,
			width = widthStr,
			height = heightStr,
			tooltip = '',
			caption = "Debug ",
			fontSize = btnFontSize,
			OnClick = {
				function()
					if Spring.GetGameRulesParam("gameMode") == "develop" then
						Spring.SendLuaRulesMsg("setGameMode|test")
						dbgBtn:SetCaption("Debug Off")
					else
						Spring.SendLuaRulesMsg("setGameMode|develop")
						dbgBtn:SetCaption("Debug On")
					end
				end
			}
		}
		if Spring.GetGameRulesParam("gameMode") == "develop" then
			dbgBtn:SetCaption("Debug On")
		else
			dbgBtn:SetCaption("Debug Off")
		end
	end

	if WG.Profiler then
		curr_x = curr_x + el_size + padding
		local btnProf
		btnProf = Chili.Button:New {
			parent = window,
			x = ('%f%%'):format(curr_x),
			bottom = 0,
			width = widthStr,
			height = heightStr,
			tooltip = '',
			caption = "Toggle profiling",
			OnClick = {function()
				if WG.Profiler.IsStarted() then
					WG.Profiler.Stop()
					-- btnProf:SetCaption("Stop profiling")
				else
					WG.Profiler.Start()
					-- btnProf:SetCaption("Start profiling")
				end
			end
			}
		}
		-- if WG.Profiler.IsStarted() then
		-- 	btnProf:SetCaption("Stop profiling")
		-- else
		-- 	btnProf:SetCaption("Start profiling")
		-- end
	end
end

function CheatIfNeeded()
	if not Spring.IsCheatingEnabled() then
		Spring.SendCommands("cheat")
	end
end

function widget:TextCommand(command)
	if command == COMMAND_NAME then
		ToggleWindowVisibility()
	end
end

function widget:Initialize()
	Spring.SendCommands('console 0')
	if Spring.GetGameRulesParam("gameMode") == "play" then
		widgetHandler:RemoveWidget(self)
		return
	end
	Chili = WG.SBChili or WG.Chili
	screen = Chili.Screen0
	if WG.Connector then
		self.openFileCallback = function(cmd)
			Spring.Echo('Opened in editor: ' .. tostring(cmd.path))
		end
		WG.Connector.Register("OpenFileFinished", self.openFileCallback)
	end
	Spring.SendCommands('bind f8 ' .. COMMAND_NAME)
	Spring.SendCommands('console 0')
end

function widget:Shutdown()
	Spring.SendCommands('unbind f8 ' .. COMMAND_NAME)
	if window then
		window:Dispose()
	end
	if WG.Connector then
		WG.Connector.Unregister("OpenFileFinished", self.openFileCallback)
	end
end

function widget:GetConfigData()
	return cfg
end

function widget:SetConfigData(data)
	for k, v in pairs(data) do
		cfg[k] = v
	end

	loadWindow()

	-- Initialization which depends on the content
	ReloadAllMessages()
	if not cfg.visible then
		window:SetVisibility(false)
	end
end


local function processLine(line)
	-- get data from player roster
	local roster = Spring.GetPlayerRoster()
	local names = {}
	for i=1,#roster do
		names[roster[i][1]] = true
	end
	-------------------------------
	local name = ''
	local isError = false
	local dedup = cfg.msgCap
	--if (names[ssub(line,2,(sfind(line,"> ") or 1)-1)] ~= nil) then
	--		-- Player Message
	--		return _, true, _ --ignore
	--elseif (names[ssub(line,2,(sfind(line,"] ") or 1)-1)] ~= nil) then
	--		-- Spec Message
	--		return _, true, _ --ignore
	--elseif (names[ssub(line,2,(sfind(line,"(replay)") or 3)-3)] ~= nil) then
	--		-- Spec Message (replay)
	--		return _, true, _ --ignore
	--elseif (names[ssub(line,1,(sfind(line," added point: ") or 1)-1)] ~= nil) then
	--		-- Map point
	--		return _, true, _ --ignore
	--elseif (ssub(line,1,1) == ">") then
	--		-- Game Message
	--		text = ssub(line,3)
	--		if ssub(line,1,3) == "> <" then --player speaking in battleroom
	--				return _, true, _ --ignore
	--		end
	--else
		text = line
	--end
	local lowerLine = slower(line)
	if sfind(lowerLine, "error") or sfind(lowerLine, "failed") then
		textColor = color.error
		isError = true
	elseif sfind(lowerLine,"warning") then
		textColor = color.warning
	else
		textColor = color.other
		if cfg.onlyErrorsAndWarnings then
			return _, true, _ --ignore
		end
	end
	line = textColor .. text
	return line, false, dedup, isError
end

local function AddConsoleLine(msg)
	-- parse the new line
	local text, ignore, dedup, isError = processLine(msg)
	if ignore then return end
	if isError then
		totalErrors = totalErrors + 1
	end
	-- check for duplicates
	-- for i=0, dedup-1 do
	-- 	local prevMsg = log.lines[#log.lines - i]
	-- 	if prevMsg and (text == prevMsg.text or text == prevMsg.origText) then
	-- 	if not prevMsg.duplicates then
	-- 	prevMsg.duplicates = 1
	-- 	end
	-- 	prevMsg.duplicates = prevMsg.duplicates + 1
	-- 	prevMsg.origText = text
	-- 	--log:UpdateLine(#log.lines - 1, color.blue ..(prevMsg.duplicates + 1)..'x \b'..text)
	-- 	return
	-- 	end
	-- end
	NewConsoleLine(text)
	if isError and cfg.popupOnError and not cfg.visible then
		ToggleWindowVisibility()
	end
end

function widget:AddConsoleLine(msg)
	AddConsoleLine(msg)
	UpdateFilterProblems()
end

function CheckForLuaFilePath(text)
	local matched = string.match(text, "%w+/-_")
	if not matched then
		return
	end

	local s, e = string.find(text, matched)
	while e < #text do
		e = e + 1
		local current = text:sub(s, e)
		if current:sub(-4) == ".lua" then
			return current, nil, s, e
		end
	end
end

function NewConsoleLine(text)
	-- avoid creating insane numbers of children (chili can't handle it)
	-- if #log.children > cfg.msgCap then
		-- log:RemoveChild(log.children[1])
	-- end
	local filePath, lineNumber, s, e = CheckForLuaFilePath(text)
	if not (filePath and WG.Connector and VFS.GetFileAbsolutePath) then
		log:AddLine(text, {}, {})
		return
	end

	filePath = filePath:lower()
	local archiveName = VFS.GetArchiveContainingFile(filePath)
	if archiveName ~= (Game.gameName .. " " .. Game.gameVersion) then
		log:AddLine(text, {}, {})
		return
	end

	local absPath = VFS.GetFileAbsolutePath(filePath)
	local tooltip = {
		startIndex = s + 3,
		endIndex = e + 3,
		tooltip = 'Open: ' .. text:sub(s, e)
	}
	text = text:sub(1, s-1) .. '\255\150\100\255' ..
		   text:sub(s, e) .. '\b' .. text:sub(1, 4) .. text:sub(e+1)
	local OnTextClick = {
		startIndex = s,
		endIndex = e,
		OnTextClick = {
			function()
				WG.Connector.Send("OpenFile", { path = absPath })
			end
		}
	}
	log:AddLine(text, {tooltip}, {OnTextClick})
end

function RemoveAllMessages()
	totalErrors = 0
	log.text = nil
	log:SetText("")
	UpdateFilterProblems()
end

function ReloadAllMessages()
	RemoveAllMessages()
	local buffer = Spring.GetConsoleBuffer(cfg.reloadLines)
	if cfg.onlySinceLastReload then
		local reloadCount = 0
		for _, l in ipairs(buffer) do
			if sfind(l.text, "LuaUI Entry Point") or sfind(l.text, "LuaRules Entry Point") then
				reloadCount = reloadCount + 1
				-- allow one for initial luaui load, and one for initial luarules load;
				-- beyond that, on initial load, show only msgs since last reload; fails if we don't have enough buffer
				if reloadCount > 2 then
					RemoveAllMessages()
				end
			elseif sfind(l.text, "%[ReloadOrRestart%]") then
				reloadCount = 0
				RemoveAllMessages()
			end
			widget:AddConsoleLine(l.text)
		end
	else
		for _, l in ipairs(buffer) do
			widget:AddConsoleLine(l.text)
		end
	end
	UpdateFilterProblems()
end

function ShowSinceReload()
	RemoveAllMessages()
	local buffer = Spring.GetConsoleBuffer(cfg.reloadLines)
	for _,l in ipairs(buffer) do
		if sfind(l.text,"LuaUI Entry Point") or sfind(l.text,"LuaRules Entry Point") then
			RemoveAllMessages()
		end
		widget:AddConsoleLine(l.text)
	end
end

--[[
function widget:GameFrame(n)
	n = n + math.floor(2-4*math.random())
	Spring.Echo("Error "..n)
end
]]

WG.DevConsole = {
	SetVisibility = SetWindowVisibility
}