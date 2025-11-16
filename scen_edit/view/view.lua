View = LCS.class{}

function View:init()
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

    -- Try to initialize RmlUi if available
    self.useRmlUi = false
    if RmlUi then
        -- Load RmlUi infrastructure
        SB.Include(Path.Join(SB.DIRS.SRC, 'view/rmlui_manager.lua'))
        SB.Include(Path.Join(SB.DIRS.SRC, 'view/rmlui_builder.lua'))

        if SB.rmlui:Initialize() then
            self.useRmlUi = true
            Log.Notice("View: Using RmlUi for UI rendering")
            self:InitializeRmlUi()
        else
            Log.Warning("View: RmlUi initialization failed, falling back to Chili")
        end
    else
        Log.Notice("View: RmlUi not available, using Chili UI")
    end

    -- Fallback to Chili if RmlUi not available or failed
    if not self.useRmlUi then
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
    self:PopulateEditorButtons(self.currentTab)

    -- Setup event handlers
    self:SetupRmlUiEvents()

    Log.Notice("RmlUi UI initialized successfully - editors use field compatibility layer")
end

function View:SetupRmlUiEvents()
    if not self.mainDocument then
        return
    end

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
            local dialog = RmlUiNewProjectDialog({
                onConfirm = function(data)
                    Log.Notice("Creating project: " .. (data.name or "unnamed"))
                    -- TODO: Actually create project
                    return true
                end
            })
            dialog:Show()
        end)
    end

    -- Open Project button
    local btnOpen = self.mainDocument:GetElementById("btn-open-project")
    if btnOpen then
        btnOpen:AddEventListener("click", function()
            local dialog = RmlUiFileDialog({
                title = "Open Project",
                directory = SB.DIRS.PROJECTS or "/",
                onConfirm = function(path)
                    Log.Notice("Opening project: " .. (path or "none"))
                    -- TODO: Actually open project
                    return true
                end
            })
            dialog:Show()
        end)
    end

    -- Save Project button
    local btnSave = self.mainDocument:GetElementById("btn-save-project")
    if btnSave then
        btnSave:AddEventListener("click", function()
            local dialog = RmlUiFileDialog({
                title = "Save Project",
                directory = SB.DIRS.PROJECTS or "/",
                onConfirm = function(path)
                    Log.Notice("Saving project: " .. (path or "none"))
                    -- TODO: Actually save project
                    return true
                end
            })
            dialog:Show()
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
        if self.mainDocument then
            if visible then
                self.mainDocument:Show()
            else
                self.mainDocument:Hide()
            end
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
        if self.statusWindow then
            self.statusWindow:Update()
        end
        if self.topLeftMenu then
            self.topLeftMenu:Update()
        end
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
        buttonsHTML = buttonsHTML .. string.format([[
            <div id="%s" class="editor-button">
                <div class="editor-button-label">%s</div>
            </div>
        ]], btnId, editorCfg.caption)
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
        local html = '<div class="editor-container"><h3 class="editor-title">' ..
                     (editorCfg and editorCfg.caption or editorName) .. '</h3>'

        if editor.generatedRml then
            html = html .. editor.generatedRml
        else
            html = html .. '<p>Editor has no fields defined</p>'
        end

        html = html .. '</div>'
        mainContent.inner_rml = html

        -- Bind field events
        self:BindFieldEvents(editor)

        -- Mark editor as visible
        editor.hidden = false
    end

    -- Highlight pressed button
    self:UpdateEditorButtonStates(editorName)
end

function View:BindFieldEvents(editor)
    if not self.mainDocument or not editor or not editor.fields then
        return
    end

    -- Bind change events for each field
    for fieldName, field in pairs(editor.fields) do
        local inputElement = self.mainDocument:GetElementById("field-" .. fieldName)
        if inputElement then
            inputElement:AddEventListener("change", function(event)
                -- Checkboxes use 'checked' property, other inputs use 'value'
                local value
                if inputElement:HasAttribute("type") and inputElement:GetAttribute("type") == "checkbox" then
                    value = inputElement.checked
                else
                    value = inputElement.value
                end
                -- Update field value
                field.value = value
                -- Notify editor
                if editor.OnFieldChange then
                    editor:OnFieldChange(fieldName, value)
                end
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
