function widget:GetInfo()
	return {
		name    = 'Developer Console RMLUI',
		desc    = 'Displays useful information for developers (RmlUi edition)',
		author  = 'Bluestone, gajop, GoogleFrog, Codex',
		date    = '2016+',
		license = 'GNU GPL v2',
		layer   = 5000,
		enabled = true,
	}
end

local RML_CONTEXT_NAME   = "shared"
local RML_DOCUMENT_PATH  = "LuaUI/rmlui/dbg_dev_console.html"
local COMMAND_NAME       = "toggleDevConsole"

local cfg = {
	msgCap = 200,          -- UI keeps at most this many lines
	reloadLines = 50000,   -- max lines to scan from engine console
	visible = true,
	onlyErrorsAndWarnings = false,
	popupOnError = true,
	popupOnWarning = false,
	onlySinceLastReload = true,
}

local severityClass = {
	error = "severity-error",
	warning = "severity-warning",
	info = "severity-info",
}

local debugButtonEnabled = false
local profilerButtonEnabled = false

local Spring    = Spring
local VFS       = VFS
local Game      = Game

local rml = {
	context = nil,
	document = nil,
	elements = {},
}

-- ========= State that must exist before helpers =========
local logEntries, totalErrors = {}, 0
local mouseCaptured = false
local first_load = true

-- Forward-declare functions used before definition
local UpdateFilterProblems
local RemoveAllMessages
local ProcessLine
local AppendLogLine

-- -------- Performance helpers (use locals above) --------
local batching = { depth = 0, dirty = false }   -- DOM batching guard

local function BeginBatch()
	batching.depth = batching.depth + 1
end

local function EndBatch()
	batching.depth = batching.depth - 1
	if batching.depth <= 0 then
		batching.depth = 0
		if batching.dirty then
			batching.dirty = false
			-- Do the actual repaint + caption update once
			local container = rml.elements["log-container"]
			if container then
				container.inner_rml = table.concat(logEntries)
				container.scroll_top = container.scroll_height
			end
			if UpdateFilterProblems then UpdateFilterProblems() end
		end
	end
end

-- ---------- Utils ----------
local function IsRmlAvailable()
	return type(RmlUi) == "table"
end

local function EscapeForRml(text)
	if not text or text == "" then return "" end
	text = text:gsub("&", "&amp;")
	text = text:gsub("<", "&lt;")
	text = text:gsub(">", "&gt;")
	return text
end

local function EscapeAttribute(text)
	if not text or text == "" then return "" end
	text = EscapeForRml(text)
	text = text:gsub("\"", "&quot;")
	text = text:gsub("'", "&apos;")
	return text
end

local function StripColorCodes(text)
	if not text then return "" end
	text = text:gsub("\255...", "")
	text = text:gsub("\b", "")
	return text
end

local function SetContextDimensions(context, x, y)
	-- context:SetDimensions(x, y)
end

local function ConsoleContains(x, y)
	local console = rml.elements and rml.elements["console"]
	if not (console and rml.context) then
		return false
	end
	return console:IsPointWithinElement(RmlUi.Vector2f.new(x, y))
end

-- ---------- Rml init ----------
local function EnsureRmlContext()
	if rml.context and rml.document then
		return true
	end
	if not IsRmlAvailable() then
		return false
	end

	local context = RmlUi.GetContext(RML_CONTEXT_NAME)
	if not context then
		return false
	end

	local document = context:LoadDocument(RML_DOCUMENT_PATH, widget)
	if not document then
		return false
	end

	document:ReloadStyleSheet()
	document:Show()
	context:EnableMouseCursor(true)

	rml.context = context
	rml.document = document
	return true
end

local function CacheElements()
	if not rml.document then return end
	local ids = {
		"console", "btn-visibility", "log-container", "btn-filter-problems",
		"btn-session", "btn-cheating", "btn-globallos", "btn-godmode",
		"btn-popup", "btn-debug-mode", "btn-profiler",
	}
	for _, id in ipairs(ids) do
		rml.elements[id] = rml.document:GetElementById(id)
	end
end

-- ---------- UI helpers ----------
local function SetButtonToggle(element, active)
	if not element then return end
	element:SetClass("is-active", active)
	element:SetAttribute("aria-pressed", active and "true" or "false")
end

local function UpdateVisibilityState()
	if not rml.document then return end
	if cfg.visible then
		rml.document:Show()
	else
		rml.document:Hide()
	end
	local btnVisibility = rml.elements["btn-visibility"]
	if btnVisibility then
		local label = cfg.visible and "Hide (F8)" or "Show (F8)"
		btnVisibility.inner_rml = EscapeForRml(label)
	end
end

-- Repaint log once unless not allowed by batching
local function RefreshLogElement(prebuilt_html)
	local container = rml.elements["log-container"]
	if not container then return end
	if batching.depth > 0 then
		batching.dirty = true
		return
	end
	container.inner_rml = prebuilt_html or table.concat(logEntries)
	container.scroll_top = container.scroll_height
end

local function ClearLog()
	logEntries = {}
	totalErrors = 0
	-- repaint deferred; caller/batch will repaint
end

UpdateFilterProblems = function()
	local btn = rml.elements["btn-filter-problems"]
	if not btn then
		return
	end

	-- Count warnings (scan markup; cheap since only ~200 lines)
	local warningCount = 0
	for _, line in ipairs(logEntries) do
		if line:find("severity%-warning") then
			warningCount = warningCount + 1
		end
	end

	-- Decide color for the number only
	local color
	if totalErrors > 0 then
		color = "#ff6b6b"   -- red
	elseif warningCount > 0 then
		color = "#ffb84d"   -- yellow
	else
		color = "#5fc8a0"   -- teal
	end

	-- Inject a colored span for the number
	local caption = string.format(
		'Problems (<span style="color:%s;">%d</span>)',
		color,
		totalErrors
	)

	btn.inner_rml = caption
	SetButtonToggle(btn, cfg.onlyErrorsAndWarnings)
end


local function UpdateToolbarState()
	SetButtonToggle(rml.elements["btn-session"],      cfg.onlySinceLastReload)
	SetButtonToggle(rml.elements["btn-popup"],        cfg.popupOnError)
	SetButtonToggle(rml.elements["btn-cheating"],     Spring.IsCheatingEnabled())
	SetButtonToggle(rml.elements["btn-globallos"],    Spring.GetGlobalLos(Spring.GetMyAllyTeamID()))
	SetButtonToggle(rml.elements["btn-godmode"],      Spring.IsGodModeEnabled())
end

local function UpdateOptionalButtons()
	if debugButtonEnabled then
		local btn = rml.elements["btn-debug-mode"]
		if btn then
			local mode = Spring.GetGameRulesParam("gameMode")
			local isDevelop = (mode == "develop")
			btn.inner_rml = EscapeForRml(isDevelop and "Debug On" or "Debug Off")
			SetButtonToggle(btn, isDevelop)
		end
	end
	if profilerButtonEnabled then
		local btn = rml.elements["btn-profiler"]
		if btn and WG.Profiler and WG.Profiler.IsStarted then
			local running = WG.Profiler.IsStarted()
			btn.inner_rml = EscapeForRml(running and "Stop profiling" or "Start profiling")
			SetButtonToggle(btn, running)
		end
	end
end

-- ---------- Log line building ----------
local function BuildLogMarkup(text, severity, fileInfo)
	local className = severityClass[severity or "info"] or severityClass.info
	if not text or text == "" then return "" end

	if fileInfo then
		local before = text:sub(1, fileInfo.startIdx - 1)
		local target = text:sub(fileInfo.startIdx, fileInfo.endIdx)
		local after  = text:sub(fileInfo.endIdx + 1)

		local dataPath = EscapeAttribute(fileInfo.absPath or fileInfo.path)
		local dataLine = fileInfo.line and tostring(fileInfo.line) or ""

		return string.format(
			'<div class="log-line %s">%s<span class="log-link" data-path="%s" data-line="%s" onclick="widget:OnLogLinkClicked(event)">%s</span>%s</div>',
			className,
			EscapeForRml(before),
			dataPath,
			EscapeAttribute(dataLine),
			EscapeForRml(target),
			EscapeForRml(after)
		)
	end

	return string.format('<div class="log-line %s">%s</div>', className, EscapeForRml(text))
end

local function DetectLuaFilePath(text)
	if not (WG.Connector and VFS.GetFileAbsolutePath) then
		return nil
	end

	local candidate, line = text:match("([%w_./\\%-]+%.lua):?(%d*)")
	if not candidate then return nil end

	local archiveName = VFS.GetArchiveContainingFile(candidate:lower())
	if archiveName ~= (Game.gameName .. " " .. Game.gameVersion) then
		return nil
	end

	local absPath = VFS.GetFileAbsolutePath(candidate)
	if not absPath then return nil end

	local startIdx, endIdx = text:find(candidate, 1, true)
	if not startIdx or not endIdx then return nil end

	return {
		path = candidate,
		absPath = absPath,
		line = tonumber(line),
		startIdx = startIdx,
		endIdx = endIdx,
	}
end

-- Fast path: only do VFS lookups for problem lines that mention ".lua"
ProcessLine = function(msg)
	local cleanText = StripColorCodes(msg)
	if cleanText == "" then
		return nil, true, false
	end

	local lower = cleanText:lower()

	if cfg.onlyErrorsAndWarnings then
		local isProblem = lower:find("error", 1, true)
		               or lower:find("failed", 1, true)
		               or lower:find("warning", 1, true)
		if not isProblem then
			return nil, true, false
		end
	end

	local severity, isError = "info", false
	if lower:find("error", 1, true) or lower:find("failed", 1, true) then
		severity, isError = "error", true
	elseif lower:find("warning", 1, true) then
		severity = "warning"
	end

	local fileInfo = nil
	if severity ~= "info" and cleanText:find(".lua", 1, true) then
		fileInfo = DetectLuaFilePath(cleanText)
	end

	local markup = BuildLogMarkup(cleanText, severity, fileInfo)
	if not markup or markup == "" then
		return nil, true, isError
	end
	return markup, false, isError
end

-- Append without repaint; compact occasionally
AppendLogLine = function(markup, isError)
	logEntries[#logEntries + 1] = markup

	-- burst-compact: avoid O(n) table.remove(1)
	-- only compact when we significantly exceed cap (4x)
	if #logEntries > cfg.msgCap * 4 then
		local new = {}
		local start = #logEntries - cfg.msgCap + 1
		if start < 1 then start = 1 end
		for i = start, #logEntries do
			new[#new + 1] = logEntries[i]
		end
		logEntries = new
	end

	if isError then
		totalErrors = totalErrors + 1
	end
end

-- ---------- High-level ops ----------
RemoveAllMessages = function()
	ClearLog()
	UpdateFilterProblems()
	-- repaint deferred; caller/batch will repaint
end

local function ReloadAllMessages()
	BeginBatch()

	RemoveAllMessages()

	local buffer = Spring.GetConsoleBuffer(cfg.reloadLines)
	if not buffer then
		-- mark dirty so EndBatch paints empty UI
		batching.dirty = true
		EndBatch()
		return
	end

	if cfg.onlySinceLastReload then
		local seenLuaUI = false
		local seenLuaRules = false
		for _, entry in ipairs(buffer) do
			local text = entry.text
			if text:find("LuaUI Entry Point", 1, true) then
				if seenLuaUI then
					ClearLog()
				end
				seenLuaUI = true
			elseif text:find("LuaRules Entry Point", 1, true) then
				if seenLuaRules then
					ClearLog()
				end
				seenLuaRules = true
			elseif text:find("%[ReloadOrRestart%]") then
				seenLuaUI = false
				seenLuaRules = false
				ClearLog()
			end
			local markup, ignore, isError = ProcessLine(text)
			if not ignore and markup then
				AppendLogLine(markup, isError)
			end
		end
	else
		for _, entry in ipairs(buffer) do
			local markup, ignore, isError = ProcessLine(entry.text)
			if not ignore and markup then
				AppendLogLine(markup, isError)
			end
		end
	end

	-- enforce cap once (keep last msgCap)
	if #logEntries > cfg.msgCap then
		local start = #logEntries - cfg.msgCap + 1
		local compact = {}
		for i = start, #logEntries do
			compact[#compact + 1] = logEntries[i]
		end
		logEntries = compact
	end

	-- mark for a single repaint & caption update
	batching.dirty = true
	EndBatch()
end

local function SetWindowVisibility(visible)
	cfg.visible = visible
	UpdateVisibilityState()
	if not visible then
		mouseCaptured = false
		assert(rml.context, "Dev console context missing during hide")
		rml.context:ProcessMouseLeave()
	end
end

local function ToggleWindowVisibility()
	SetWindowVisibility(not cfg.visible)
end

local function SetFilterMessages(flag)
	cfg.onlyErrorsAndWarnings = flag
	ReloadAllMessages()
	UpdateFilterProblems()
end

local function SetFilterSinceLastReload(flag)
	cfg.onlySinceLastReload = flag
	ReloadAllMessages()
	SetButtonToggle(rml.elements["btn-session"], cfg.onlySinceLastReload)
end

local function SetPopUpOnError(flag)
	cfg.popupOnError = flag
	SetButtonToggle(rml.elements["btn-popup"], cfg.popupOnError)
end

local function CheatIfNeeded()
	if not Spring.IsCheatingEnabled() then
		Spring.SendCommands("cheat")
	end
end

local function IsInteractive()
	return cfg.visible and rml.context and rml.document and not Spring.IsGUIHidden()
end

-- ---------- Widget lifecycle ----------
function widget:Initialize()
	if Spring.GetGameRulesParam("useRml") ~= "true" then
		return
	end
	Spring.SendCommands('console 0')
	if Spring.GetGameRulesParam("gameMode") == "play" then
		widgetHandler:RemoveWidget(self)
		return
	end

	if not EnsureRmlContext() then
		Spring.Log(widget:GetInfo().name, "error", "RmlUi unavailable; disabling developer console")
		widgetHandler:RemoveWidget(self)
		return
	end

	CacheElements()

	if rml.elements["btn-debug-mode"] then
		debugButtonEnabled = not WG.SB
		rml.elements["btn-debug-mode"]:SetClass("hidden", not debugButtonEnabled)
	end
	if rml.elements["btn-profiler"] then
		profilerButtonEnabled = WG.Profiler ~= nil
		rml.elements["btn-profiler"]:SetClass("hidden", not profilerButtonEnabled)
	end

	UpdateVisibilityState()
	UpdateToolbarState()
	UpdateOptionalButtons()
	UpdateFilterProblems()
	ReloadAllMessages()
end

function widget:Shutdown()
	if rml.document then
		rml.document:Close()
	end
	rml.context = nil
	rml.document = nil
	rml.elements = {}
	mouseCaptured = false
	WG.DevConsole = nil
	Spring.SendCommands('console 1')
end

function widget:ViewResize(vsx, vsy)
	if rml.context then
		SetContextDimensions(rml.context, vsx, vsy)
	end
end

function widget:Update()
	if rml.context then
		rml.context:Update()
	end
	UpdateToolbarState()
	UpdateOptionalButtons()
	if first_load then
		RefreshLogElement()
		first_load = false
	end
end

function widget:DrawScreen()
	if not cfg.visible or Spring.IsGUIHidden() then
		return
	end
	if rml.context then
		rml.context:Render()
	end
end

-- ---------- Mouse / input ----------
function widget:MouseMove(x, y, dx, dy, button)
	if not IsInteractive() then return false end
	local inside = ConsoleContains(x, y)
	local interacting = rml.context.IsMouseInteracting and rml.context:IsMouseInteracting()
	if not inside and not interacting then
		if mouseCaptured and rml.context.ProcessMouseLeave then
			rml.context:ProcessMouseLeave()
		end
		mouseCaptured = false
		return false
	end
	rml.context:ProcessMouseMove(x, y, 0)
	mouseCaptured = inside or interacting
	return inside or interacting
end

function widget:MousePress(x, y, button)
	if not IsInteractive() then return false end
	local inside = ConsoleContains(x, y)
	if not inside and not mouseCaptured then return false end
	rml.context:ProcessMouseMove(x, y, 0)
	mouseCaptured = true
	return rml.context:ProcessMouseButtonDown(button - 1, 0)
end

function widget:MouseRelease(x, y, button)
	if not IsInteractive() then return false end
	local inside = ConsoleContains(x, y) or mouseCaptured
	if not inside then return false end
	rml.context:ProcessMouseMove(x, y, 0)
	local handled = rml.context:ProcessMouseButtonUp(button - 1, 0)
	mouseCaptured = rml.context.IsMouseInteracting and rml.context:IsMouseInteracting()
	return handled
end

function widget:MouseWheel(up, value)
	if not IsInteractive() then return false end
	local mx, my = Spring.GetMouseState()
	local inside = ConsoleContains(mx, my)
	if not inside then return false end
	rml.context:ProcessMouseMove(mx, my, 0)
	local delta = up and value or -value
	return rml.context:ProcessMouseWheel(delta, 0)
end

-- ---------- Commands / events ----------
function widget:TextCommand(command)
	if command == COMMAND_NAME then
		ToggleWindowVisibility()
		return true
	end
end

function widget:AddConsoleLine(msg)
	local markup, ignore, isError = ProcessLine(msg)
	if ignore or not markup then
		return
	end
	AppendLogLine(markup, isError)
	-- For live lines, repaint once (cheap; single line)
	RefreshLogElement()
	if isError then
		UpdateFilterProblems()
	end
end

function widget:OnToggleVisibilityClicked()
	ToggleWindowVisibility()
end

function widget:OnClearClicked()
	RemoveAllMessages()
	RefreshLogElement("")
end

function widget:OnFilterProblemsClicked()
	SetFilterMessages(not cfg.onlyErrorsAndWarnings)
end

function widget:OnSessionFilterClicked()
	SetFilterSinceLastReload(not cfg.onlySinceLastReload)
end

function widget:OnReloadLuaUIClicked()
	Spring.SendCommands("luaui reload")
end

function widget:OnReloadLuaRulesClicked()
	CheatIfNeeded()
	Spring.SendCommands("luarules reload")
end

function widget:OnToggleCheating()
	Spring.SendCommands("cheat")
	SetButtonToggle(rml.elements["btn-cheating"], Spring.IsCheatingEnabled())
end

function widget:OnToggleGlobalLos()
	CheatIfNeeded()
	Spring.SendCommands("globallos")
	SetButtonToggle(rml.elements["btn-globallos"], Spring.GetGlobalLos(Spring.GetMyAllyTeamID()))
end

function widget:OnToggleGodMode()
	CheatIfNeeded()
	Spring.SendCommands("godmode")
	SetButtonToggle(rml.elements["btn-godmode"], Spring.IsGodModeEnabled())
end

function widget:OnRestartClicked()
	local script = VFS.LoadFile("_script.txt")
	if script then
		Spring.Reload(script)
	else
		Spring.Log(widget:GetInfo().name, "error", "Unable to reload: _script.txt missing")
	end
end

function widget:OnTogglePopupClicked()
	SetPopUpOnError(not cfg.popupOnError)
end

function widget:OnToggleDebugMode()
	if Spring.GetGameRulesParam("gameMode") == "develop" then
		Spring.SendLuaRulesMsg("setGameMode|test")
	else
		Spring.SendLuaRulesMsg("setGameMode|develop")
	end
	UpdateOptionalButtons()
end

function widget:OnToggleProfiler()
	if not WG.Profiler then return end
	if WG.Profiler.IsStarted() then
		WG.Profiler.Stop()
	else
		WG.Profiler.Start()
	end
	UpdateOptionalButtons()
end

function widget:OnLogLinkClicked(event)
	local element = event.current_element
	if not element or not WG.Connector then return end
	local path = element:GetAttribute("data-path")
	if not path then return end
	local lineAttr = element:GetAttribute("data-line")
	local line = tonumber(lineAttr)
	local payload = { path = path }
	if line then payload.line = line end
	WG.Connector.Send("OpenFile", payload)
end

WG.DevConsole = {
	SetVisibility = SetWindowVisibility,
}
