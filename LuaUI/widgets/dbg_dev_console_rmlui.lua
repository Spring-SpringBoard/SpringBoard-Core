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


local debugButtonEnabled = false
local profilerButtonEnabled = false
local engineConsoleHidden = false

local Spring    = Spring
local VFS       = VFS
local Game      = Game

local consoleData = {
	lines = {}
}

local rml = {
	context = nil,
	document = nil,
	elements = {},
	dataModel = nil,
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
local RefreshLogElement

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
			if RefreshLogElement then RefreshLogElement() end
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


-- `x, y` are RmlUi coordinates (origin top-left), which is what the mouse
-- call-ins give us. Hit-test the document body, not `#console`: that div has no
-- height of its own (its children are positioned), so it reports ~14px tall and
-- every hit test against it failed.
local function ConsoleContains(x, y)
	if not (rml.document and rml.context) then
		return false
	end
	return rml.document:IsPointWithinElement(RmlUi.Vector2f.new(x, y))
end

-- Spring.GetMouseState is bottom-origin, so it needs flipping before it can be
-- handed to ConsoleContains. Getting this wrong made Ctrl+C a no-op.
local function CursorOverConsole()
	local mx, my = Spring.GetMouseState()
	local _, viewHeight = Spring.GetViewGeometry()
	return ConsoleContains(mx, viewHeight - my)
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

	-- Create data model BEFORE loading document (BAR example pattern)
	rml.dataModel = context:OpenDataModel("dbg_dev_console", consoleData)
	if not rml.dataModel then
		Spring.Echo("[DevConsole] Failed to create data model!")
		return false
	end
	Spring.Echo("[DevConsole] Data model created, lines:", #consoleData.lines)

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

-- ---------- Multi-line selection ----------
-- RmlUi has no text selection across elements, and each log line is its own
-- element. So select whole lines: drag across them, Ctrl+A for all, Ctrl+C to
-- copy the selected text to the clipboard.
local selection = { anchor = nil, extent = nil, dragging = false }
-- Every entry carries a stable id so a selection survives the data-model
-- rebuild that a new log line triggers. Without it, one incoming line between
-- selecting and pressing Ctrl+C dropped the selection on the floor.
local nextLineUid = 0
local selectionDirty = false

local function IndexOfUid(uid)
	if not uid then
		return nil
	end
	for index, entry in ipairs(logEntries) do
		if entry.uid == uid then
			return index
		end
	end
end

local function LogLineElements()
	local container = rml.elements and rml.elements["log-container"]
	if not container then
		return {}
	end
	return container.child_nodes or {}
end

-- Hit-test by cursor position rather than comparing elements: two Lua handles
-- to the same Rml::Element are not necessarily ==, so identity comparison is
-- unreliable.
local function IndexOfLineAt(mouseY)
	if not mouseY then
		return nil
	end
	for index, child in ipairs(LogLineElements()) do
		local top = child.absolute_top
		local height = child.offset_height or 0
		if top and mouseY >= top and mouseY <= top + height then
			return index
		end
	end
end

local function SelectionRange()
	if not (selection.anchor and selection.extent) then
		return nil, nil
	end
	local from, to = selection.anchor, selection.extent
	if from > to then
		from, to = to, from
	end
	return from, to
end

local function ApplySelectionClasses()
	local from, to = SelectionRange()
	for index, child in ipairs(LogLineElements()) do
		child:SetClass("selected", from ~= nil and index >= from and index <= to)
	end
end

local function ClearSelection()
	selection.anchor, selection.extent, selection.dragging = nil, nil, false
	selection.anchorUid, selection.extentUid = nil, nil
	ApplySelectionClasses()
end

-- Pin the current selection to line ids, so it can be found again after the
-- data model rebuilds the line elements.
local function RememberSelection()
	selection.anchorUid = selection.anchor and logEntries[selection.anchor] and logEntries[selection.anchor].uid
	selection.extentUid = selection.extent and logEntries[selection.extent] and logEntries[selection.extent].uid
end

-- The log rebuilt: map the remembered ids back to indices. A line that scrolled
-- past the cap is gone, and so is the selection.
local function ReanchorSelection()
	if not selection.anchorUid then
		return
	end
	local anchor = IndexOfUid(selection.anchorUid)
	local extent = IndexOfUid(selection.extentUid)
	if anchor and extent then
		selection.anchor, selection.extent = anchor, extent
	else
		selection.anchor, selection.extent, selection.dragging = nil, nil, false
		selection.anchorUid, selection.extentUid = nil, nil
	end
end

local function SelectAllLines()
	local lines = LogLineElements()
	if #lines == 0 then
		return
	end
	selection.anchor, selection.extent = 1, #lines
	RememberSelection()
	ApplySelectionClasses()
end

local function UnescapeRml(text)
	text = text:gsub("&lt;", "<"):gsub("&gt;", ">")
	text = text:gsub("&quot;", '"'):gsub("&apos;", "'")
	return (text:gsub("&amp;", "&"))
end

local function CopySelectionToClipboard()
	local from, to = SelectionRange()
	if not from then
		return false
	end
	local lines = LogLineElements()
	local parts = {}
	for index = from, to do
		local child = lines[index]
		if child then
			parts[#parts + 1] = UnescapeRml(tostring(child.inner_rml or ""))
		end
	end
	if #parts == 0 then
		return false
	end
	if not Spring.SetClipboard then
		return false
	end
	Spring.SetClipboard(table.concat(parts, "\n"))
	Spring.Echo("[DevConsole] Copied " .. tostring(#parts) .. " line(s) to clipboard")
	return true
end

local selectionBound = false

local function BindLogSelection()
	local container = rml.elements and rml.elements["log-container"]
	if not container or selectionBound then
		return
	end
	selectionBound = true

	container:AddEventListener("mousedown", function(event)
		local index = IndexOfLineAt(event.parameters and event.parameters.mouse_y)
		if not index then
			ClearSelection()
			return
		end
		selection.anchor, selection.extent, selection.dragging = index, index, true
		RememberSelection()
		ApplySelectionClasses()
	end)

	container:AddEventListener("mousemove", function(event)
		if not selection.dragging then
			return
		end
		local index = IndexOfLineAt(event.parameters and event.parameters.mouse_y)
		if index then
			selection.extent = index
			RememberSelection()
			ApplySelectionClasses()
		end
	end)

	container:AddEventListener("mouseup", function()
		selection.dragging = false
	end)
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

-- Repaint log once unless not allowed by batching. The log is rendered by the
-- RmlUi data model (data-for over `lines`), so "repainting" means handing the
-- current entries to the data model.
RefreshLogElement = function()
	if batching.depth > 0 then
		batching.dirty = true
		return
	end
	if not rml.dataModel then
		return
	end
	rml.dataModel.lines = logEntries

	local container = rml.elements["log-container"]
	if container then
		container.scroll_top = container.scroll_height
	end
	-- data-for rebuilds the line elements, so the selection has to be mapped back
	-- onto them, and the classes re-applied once RmlUi has rebuilt them.
	ReanchorSelection()
	selectionDirty = true
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

	local warningCount = 0
	for _, entry in ipairs(logEntries) do
		if entry.severity == "warning" then
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


local function DetectLuaFilePath(text)
	if not VFS.GetFileAbsolutePath then
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

	-- The log is rendered through the RmlUi data model (data-for over `lines`),
	-- so produce a structured entry rather than markup. The severity booleans
	-- drive the data-class bindings in dbg_dev_console.html.
	local entry = {
		text = cleanText,
		severity = severity,
		isError = isError,
		isWarning = severity == "warning",
		isInfo = severity == "info",
		path = fileInfo and (fileInfo.absPath or fileInfo.path) or nil,
		line = fileInfo and fileInfo.line or nil,
	}
	return entry, false, isError
end

-- Append without repaint; compact occasionally
AppendLogLine = function(markup, isError)
	nextLineUid = nextLineUid + 1
	markup.uid = nextLineUid
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
			if rml.context and rml.context.ProcessMouseLeave then
				rml.context:ProcessMouseLeave()
			end
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
	-- Rust owns the developer console in its UI mode. Keep this guard separate
	-- from the legacy `useRml` flag so this widget never changes engine-console
	-- state while removing itself for Rust.
	if Spring.GetGameRulesParam("sb_ui") ~= "rmlui" then
		widgetHandler:RemoveWidget(self)
		return
	end
	if Spring.GetGameRulesParam("useRml") ~= "true" then
		widgetHandler:RemoveWidget(self)
		return
	end
	Spring.SendCommands('console 0')
	engineConsoleHidden = true
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
	BindLogSelection()

	-- In RmlUi mode the Chili dev console removes itself and never binds
	-- F8, so bind it here to keep the toggle working.
	Spring.SendCommands("bind f8 " .. COMMAND_NAME)

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
	Spring.SendCommands("unbind f8 " .. COMMAND_NAME)
	if rml.document then
		rml.document:Close()
	end
	if rml.context and rml.dataModel then
		rml.context:RemoveDataModel("dbg_dev_console")
	end
	rml.context = nil
	rml.document = nil
	rml.elements = {}
	rml.dataModel = nil
	mouseCaptured = false
	WG.DevConsole = nil
	if engineConsoleHidden then
		Spring.SendCommands('console 1')
	end
end

function widget:Update()
	if rml.context then
		rml.context:Update()
	end
	if selectionDirty then
		selectionDirty = false
		ApplySelectionClasses()
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

-- ---------- Keyboard ----------
-- Ctrl+A selects every log line, Ctrl+C copies the selection. Only while the
-- cursor is over the console, so the shortcuts stay out of the way elsewhere.
function widget:KeyPress(key, mods, isRepeat)
	if not IsInteractive() or not mods.ctrl then
		return false
	end
	if not CursorOverConsole() then
		return false
	end
	if key == KEYSYMS.A then
		SelectAllLines()
		return true
	end
	if key == KEYSYMS.C then
		return CopySelectionToClipboard()
	end
	return false
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
	RefreshLogElement()
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
	if not element then return end
	local path = element:GetAttribute("data-path")
	if not path then return end
end

WG.DevConsole = {
	SetVisibility = SetWindowVisibility,
	-- SpringBoard binds Ctrl+C/Ctrl+A to Copy/Select-all and its widget runs
	-- first (layer 1001 vs 5000), so it asks whether the console wants them.
	CursorOverConsole = CursorOverConsole,
}
