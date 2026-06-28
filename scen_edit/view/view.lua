View = LCS.class{}

function View:init()
    -- Determine which UI system to use BEFORE including any files
    -- This must be done first so all includes can check SB.useRmlUi
    SB.useRmlUi = Spring.GetGameRulesParam("useRml") == "true"

    SB.IncludeDir(Path.Join(SB.DIRS.SRC, 'view'))
    SB.Include(Path.Join(SB.DIRS.SRC, 'view/main_window/main_window_panel.lua'))
    SB.IncludeDir(Path.Join(SB.DIRS.SRC, 'view/main_window'))
    SB.IncludeDir(Path.Join(SB.DIRS.SRC, 'view/actions'))

    SB.IncludeDir(Path.Join(SB.DIRS.SRC, 'view/object'))
    SB.IncludeDir(Path.Join(SB.DIRS.SRC, 'view/map'))
    SB.IncludeDir(Path.Join(SB.DIRS.SRC, 'view/trigger'))
    SB.IncludeDir(Path.Join(SB.DIRS.SRC, 'view/general'))
    SB.IncludeDir(Path.Join(SB.DIRS.SRC, 'view/floating'))
    SB.IncludeDir(Path.Join(SB.DIRS.SRC, 'view/dialog'))

    -- Initialize the appropriate UI system
    self.useRmlUi = SB.useRmlUi
    if SB.useRmlUi then
        -- Load RmlUi infrastructure
        SB.Include(Path.Join(SB.DIRS.SRC, 'view/rmlui_manager.lua'))
        SB.Include(Path.Join(SB.DIRS.SRC, 'view/rmlui_builder.lua'))

        if SB.rmlui:Initialize() then
            Log.Notice("View: Using RmlUi for UI rendering")
            self:InitializeRmlUi()
        else
            Log.Warning("View: RmlUi initialization failed, falling back to Chili")
            self.useRmlUi = false
            SB.useRmlUi = false
            self:InitializeChili()
        end
    else
        Log.Notice("View: Using Chili UI")
        self:InitializeChili()
    end

    -- Common initialization (non-UI)
    SB.clipboard = Clipboard()
    self.areaViews = {}
    self.selectionManager = SelectionManager()
    self.displayDevelop = true
    self.modelShaders = ModelShaders()
    self.__visible = true
end

function View:InitializeRmlUi()
    -- Load RmlUi field system first (maintains original AddField API - implementation-agnostic!)
    -- This makes StringField(), NumericField(), etc. create RmlUi fields instead of Chili
    SB.Include(Path.Join(SB.DIRS.SRC, 'view/rmlui_component.lua'))  -- Base class for components
    SB.Include(Path.Join(SB.DIRS.SRC, 'view/rmlui_fields.lua'))
    SB.Include(Path.Join(SB.DIRS.SRC, 'view/rmlui_field_compat.lua'))  -- Makes StringField() etc work
    SB.Include(Path.Join(SB.DIRS.SRC, 'view/ui_controls.lua'))  -- ActionButton(), EditorButton()
    SB.IncludeDir(Path.Join(SB.DIRS.SRC, 'view/rmlui_floating'))

    -- Load main UI template
    local rmlPath = Path.Join(SB.DIRS.SRC, 'view/rml/springboard_main.rml')
    self.mainDocument = SB.rmlui:LoadDocument(rmlPath, true)

    if not self.mainDocument then
        Log.Error("Failed to load RmlUi main document")
        self.useRmlUi = false
        self:InitializeChili()
        return
    end

    -- Initialize SB.editors table for lazy creation
    if not SB.editors then
        SB.editors = {}
    end

    -- Use existing TabbedWindow/MainWindowPanel infrastructure (works in both modes)
    -- This handles editor creation via SB.delay automatically
    self.tabbedWindow = TabbedWindow()

    -- Initialize tab system
    self.currentTab = "Objects"
    self:BindTabEvents()
    self:PopulateActionButtons()
    self:PopulateEditorButtons(self.currentTab)

    -- Setup event handlers
    self:SetupRmlUiEvents()

    self.commandWindow = RmlUiCommandWindow()
    self.commandWindow:Show()
    self.statusWindow = RmlUiStatusWindow()
    self.statusWindow:Show()
    self.controlButtons = RmlUiControlButtons()
    self.controlButtons:Show()
    self.topLeftMenu = RmlUiTopLeftMenu()
    self.topLeftMenu:Show()
end

function View:SetupRmlUiEvents()
    -- Exit button
    local btnExit = self.mainDocument:GetElementById("btn-exit")
    if btnExit then
        btnExit:AddEventListener("click", function()
            Spring.SendCommands("quit", "quitforce")
        end)
    end

    -- New Project button
    local btnNew = self.mainDocument:GetElementById("btn-new-project")
    if btnNew then
        btnNew:AddEventListener("click", function()
            NewProjectDialog()
        end)
    end

    -- Open Project button
    local btnOpen = self.mainDocument:GetElementById("btn-open-project")
    if btnOpen then
        btnOpen:AddEventListener("click", function()
            local cmd = LoadProjectCommand()
            SB.commandManager:execute(cmd)
        end)
    end

    -- Save Project button
    local btnSave = self.mainDocument:GetElementById("btn-save-project")
    if btnSave then
        btnSave:AddEventListener("click", function()
            local cmd = SaveProjectCommand()
            SB.commandManager:execute(cmd)
        end)
    end

    -- Team selector
    local teamSelector = self.mainDocument:GetElementById("team-selector")
    if teamSelector then
        teamSelector:AddEventListener("change", function()
            local teamID = tonumber(teamSelector.value)
            if teamID then
                SB.model.selectedTeam = teamID
                Log.Notice("Team changed to: " .. teamID)
            end
        end)
    end

    -- Play/Pause buttons
    local btnPlay = self.mainDocument:GetElementById("btn-play")
    if btnPlay then
        btnPlay:AddEventListener("click", function()
            Spring.SendCommands("pause 0")
        end)
    end

    local btnPause = self.mainDocument:GetElementById("btn-pause")
    if btnPause then
        btnPause:AddEventListener("click", function()
            Spring.SendCommands("pause 1")
        end)
    end
end

function View:InitializeChili()
    -- Load UI controls abstraction (ActionButton, EditorButton)
    SB.Include(Path.Join(SB.DIRS.SRC, 'view/ui_controls.lua'))

    self.tabbedWindow = TabbedWindow()
    self.bottomBar = BottomBar()
    self.teamSelector = TeamSelector()
    self.topLeftMenu = TopLeftMenu()
end

function View:SetVisible(visible)
    if self.__visible == visible then
        return
    end

    self.__visible = visible

    if self.useRmlUi then
        -- RmlUi visibility
        if visible then
            self.mainDocument:Show()
            self.commandWindow:Show()
            self.statusWindow:Show()
            self.controlButtons:Show()
            self.topLeftMenu:Show()
        else
            self.mainDocument:Hide()
            self.commandWindow:Hide()
            self.statusWindow:Hide()
            self.controlButtons:Hide()
            self.topLeftMenu:Hide()
        end
    else
        -- Chili visibility
        if visible then
            self.tabbedWindow.window:Show()
            self.teamSelector.cmbTeamSelector:Show()
            self.teamSelector.cbLockTeam:Show()
            self.topLeftMenu:Show()
            self.bottomBar.window:Show()
        else
            self.tabbedWindow.window:Hide()
            self.teamSelector.cmbTeamSelector:Hide()
            self.teamSelector.cbLockTeam:Hide()
            self.topLeftMenu:Hide()
            self.bottomBar.window:Hide()
        end
    end

    if WG.DevConsole then
        WG.DevConsole.SetVisibility(visible)
    end
end

function View:Update()
    if not self.useRmlUi then
        -- Chili updates
        self.teamSelector:Update()
        self.topLeftMenu:Update()
        self.bottomBar:Update()
    else
        -- RmlUi updates
        self.statusWindow:Update()
        self.topLeftMenu:Update()
        self.commandWindow:Update()
    end

    -- Common updates
    self.selectionManager:Update()
end

function View:__DrawAreas()
    gl.PushMatrix()
    for _, areaView in pairs(self.areaViews) do
        areaView:Draw()
    end
    gl.PopMatrix()
end

function View:DrawWorldPreUnit()
    if self.displayDevelop then
        self:__DrawAreas()
    end
    self.selectionManager:DrawWorldPreUnit()
end

-- RmlUi tab and editor button management
function View:BindTabEvents()
    if not self.mainDocument then return end

    -- Bind click events to all tab buttons
    local tabs = {"Objects", "Map", "Env", "Misc"}
    for _, tabName in ipairs(tabs) do
        local tabButton = self.mainDocument:GetElementById("tab-" .. tabName)
        if tabButton then
            tabButton:AddEventListener("click", function()
                self:SwitchTab(tabName)
            end)
        end
    end
end

function View:SwitchTab(tabName)
    if self.currentTab == tabName then return end

    -- Update tab button styles
    local tabs = {"Objects", "Map", "Env", "Misc"}
    for _, name in ipairs(tabs) do
        local tabButton = self.mainDocument:GetElementById("tab-" .. name)
        if tabButton then
            if name == tabName then
                tabButton:SetClass("active", true)
            else
                tabButton:SetClass("active", false)
            end
        end
    end

    self.currentTab = tabName
    self:PopulateEditorButtons(tabName)

    -- Clear main content area
    local mainContent = self.mainDocument:GetElementById("main-content")
    if mainContent then
        mainContent.inner_rml = "<p>Select an editor from the buttons above</p>"
    end
end

function View:PopulateActionButtons()
    if not SB.conf.SHOW_BASIC_CONTROLS then
        return
    end

    local actionBar = self.mainDocument:GetElementById("action-bar")
    if not actionBar then return end

    -- Filter and sort actions by toolbar_order
    local actions = Table.Filter(SB.actionRegistry, function(v)
        return v.toolbar_order ~= nil
    end)
    actions = Table.SortByAttr(actions, "toolbar_order")

    -- Create button HTML for each action
    local buttonsHTML = ""
    for _, actionCfg in ipairs(actions) do
        if actionCfg.image and actionCfg.tooltip then
            local btnId = "toolbar-action-" .. (actionCfg.name or actionCfg.tooltip:gsub("%s+", "-"):lower())

            -- Make image path relative to RML document
            local imagePath = actionCfg.image
            if imagePath:sub(1, 6) == "LuaUI/" then
                imagePath = "../../../" .. imagePath
            end

            buttonsHTML = buttonsHTML .. string.format([[
                <button id="%s" class="toolbar-action-button" title="%s">
                    <img src="%s"/>
                </button>
            ]], btnId, actionCfg.tooltip, imagePath)
        end
    end

    actionBar.inner_rml = buttonsHTML

    -- Bind click events for action buttons
    for _, actionCfg in ipairs(actions) do
        if actionCfg.image and actionCfg.tooltip then
            local btnId = "toolbar-action-" .. (actionCfg.name or actionCfg.tooltip:gsub("%s+", "-"):lower())
            local btnElement = self.mainDocument:GetElementById(btnId)
            if btnElement then
                btnElement:AddEventListener("click", function()
                    local action = actionCfg.action()
                    if not action.canExecute or action:canExecute() then
                        action:execute()
                    end
                end)
            end
        end
    end
end

function View:PopulateEditorButtons(tabName)
    local editorPanel = self.mainDocument:GetElementById("editor-button-panel")
    if not editorPanel then return end

    -- Clear existing buttons
    editorPanel.inner_rml = ""

    -- Get all editors for this tab from editorRegistry
    local editors = {}
    for name, editorCfg in pairs(SB.editorRegistry) do
        if editorCfg.tab == tabName then
            table.insert(editors, editorCfg)
        end
    end

    -- Sort by order
    table.sort(editors, function(a, b)
        if a.order ~= b.order then
            return a.order < b.order
        end
        return a.caption < b.caption
    end)

    -- Create button HTML for each editor
    local buttonsHTML = ""
    for _, editorCfg in ipairs(editors) do
        local btnId = "editor-btn-" .. editorCfg.name

        -- Convert image path to be relative to RML document
        local iconHTML = ""
        if editorCfg.image then
            local imagePath = editorCfg.image
            if imagePath:sub(1, 6) == "LuaUI/" then
                -- RML is in scen_edit/view/rml/, images are in LuaUI/images/
                -- Need to go up 3 levels: rml -> view -> scen_edit -> root
                imagePath = "../../../" .. imagePath
            end
            iconHTML = string.format('<img src="%s" class="editor-button-icon"/>', imagePath)
        end

        buttonsHTML = buttonsHTML .. string.format([[
            <div id="%s" class="editor-button">
                %s
                <div class="editor-button-label">%s</div>
            </div>
        ]], btnId, iconHTML, editorCfg.caption)
    end

    editorPanel.inner_rml = buttonsHTML

    -- Bind click events to editor buttons
    for _, editorCfg in ipairs(editors) do
        local btnId = "editor-btn-" .. editorCfg.name
        local btn = self.mainDocument:GetElementById(btnId)
        if btn then
            btn:AddEventListener("click", function()
                self:OpenEditor(editorCfg.name)
            end)
        end
    end
end

function View:OpenEditor(editorName)
    Log.Notice("Opening editor: " .. editorName)

    -- Create editor on-demand if not yet created by SB.delay
    if not SB.editors[editorName] then
        local editorCfg = SB.editorRegistry[editorName]
        if editorCfg and editorCfg.editor then
            Log.Notice("Creating editor on-demand: " .. editorName)
            SB.editors[editorName] = editorCfg.editor()
        else
            Log.Error("Editor not found in registry: " .. editorName)
            return
        end
    end

    local editor = SB.editors[editorName]
    local editorCfg = SB.editorRegistry[editorName]
    local mainContent = self.mainDocument:GetElementById("main-content")

    if mainContent and editor then
        -- Use pre-generated RML from Finalize()
        local html = '<div class="editor-container">'

        if editor.generatedRml then
            html = html .. editor.generatedRml
        else
            html = html .. '<p>Editor has no fields defined</p>'
        end

        html = html .. '</div>'
        mainContent.inner_rml = html

        -- Bind fields to document elements
        if editor.fields then
            for _, field in pairs(editor.fields) do
                if field.BindToDocument then
                    field:BindToDocument()
                end
            end
        end

        -- Bind field events
        self:BindFieldEvents(editor)

        -- Update grid if editor has a gridView
        if editor.gridView then
            SB.delay(function()
                editor.gridView:_UpdateRmlUiGrid()
            end)
        end

        -- Update grids if editor has multiple gridViews
        if editor.gridViews then
            for _, gridView in pairs(editor.gridViews) do
                SB.delay(function()
                    gridView:_UpdateRmlUiGrid()
                end)
            end
        end

        -- Mark editor as visible
        editor.hidden = false
    end

    -- Highlight pressed button
    self:UpdateEditorButtonStates(editorName)
end

function View:BindFieldEvents(editor)
    if not editor then
        return
    end

    -- For dialogs, use editor.document; for main window, use self.mainDocument
    local document = editor.document or self.mainDocument
    if not document then
        return
    end

    -- Capture CallListeners in local scope for event listener callbacks
    local callListeners = CallListeners

    -- Bind change events for fields
    if editor.fields then
        for fieldName, field in pairs(editor.fields) do
            local inputElement = document:GetElementById("field-" .. fieldName)
            if inputElement then
                local function updateField()
                    -- Checkboxes use 'checked' attribute, other inputs use 'value'
                    local value
                    if inputElement:HasAttribute("type") and inputElement:GetAttribute("type") == "checkbox" then
                        value = inputElement:GetAttribute("checked") == "checked"
                    else
                        value = inputElement:GetAttribute("value")
                    end
                    -- Use Set() method to properly update field and trigger validation/callbacks
                    field:Set(value)
                end

                -- Listen for both change (on blur) and input (while typing) events
                inputElement:AddEventListener("change", updateField)
                -- Only add input listener for text/number inputs, not checkboxes
                if not (inputElement:HasAttribute("type") and inputElement:GetAttribute("type") == "checkbox") then
                    inputElement:AddEventListener("input", updateField)
                end
            end

            -- Bind events for fields with buttons (AssetField, ColorField, MaterialField)
            if field.BindEvents then
                field:BindEvents()
            end
        end
    end

    -- Bind click events for action buttons
    if editor.actionButtons then
        for _, button in ipairs(editor.actionButtons) do
            button:BindToDocument()
            button.element:AddEventListener("click", function(event)
                callListeners(button.OnClick)
            end)
        end
    end

    -- Bind click events for regular buttons (from AddControl)
    if editor.regularButtons then
        for _, button in ipairs(editor.regularButtons) do
            button:BindToDocument()
            button.element:AddEventListener("click", function(event)
                callListeners(button.OnClick)
            end)
        end
    end

    -- Bind events for filter controls (ComboBox, EditBox)
    if editor.filterControls then
        for _, filter in ipairs(editor.filterControls) do
            filter:BindToDocument()
            -- ComboBox: bind change event
            if filter.id:match("^filter%-combo%-") and filter.OnSelect then
                filter.element:AddEventListener("change", function(event)
                    local itemIdx = tonumber(filter.element.value)
                    filter.selected = itemIdx
                    callListeners(filter.OnSelect, filter.element, itemIdx, true)
                end)
            -- EditBox: bind input events
            elseif filter.id:match("^filter%-edit%-") then
                if filter.OnTextInput then
                    filter.element:AddEventListener("input", function(event)
                        filter.text = filter.element.value
                        local obj = { text = filter.element.value }
                        callListeners(filter.OnTextInput, obj)
                    end)
                end
                if filter.OnKeyPress then
                    filter.element:AddEventListener("keyup", function(event)
                        filter.text = filter.element.value
                        local obj = { text = filter.element.value }
                        callListeners(filter.OnKeyPress, obj)
                    end)
                end
            end
        end
    end

    -- Bind events for path navigation (AssetView)
    if editor.gridView and editor.gridView.pathNav then
        local pathNav = editor.gridView.pathNav
        local upButton = document:GetElementById(pathNav.id .. "-up")
        if upButton and pathNav.OnUpClick then
            upButton:AddEventListener("click", function(event)
                callListeners(pathNav.OnUpClick)
            end)
        end
    end
end

function View:UpdateEditorButtonStates(activeEditorName)
    -- Remove pressed state from all buttons
    for name, _ in pairs(SB.editorRegistry) do
        local btn = self.mainDocument:GetElementById("editor-btn-" .. name)
        if btn then
            btn:SetClass("pressed", name == activeEditorName)
        end
    end
end
