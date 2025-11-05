View = LCS.class{}

function View:init()
    -- Try to initialize RmlUi if available
    self.useRmlUi = false
    if Spring.RmlUi then
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
    -- Load RML template
    local rmlPath = Path.Join(SB.DIRS.SRC, 'view/rml/springboard_main.rml')
    self.mainDocument = SB.rmlui:LoadDocument(rmlPath, true)

    if not self.mainDocument then
        Log.Error("Failed to load RmlUi main document")
        self.useRmlUi = false
        self:InitializeChili()
        return
    end

    -- Setup event handlers
    self:SetupRmlUiEvents()

    Log.Notice("RmlUi UI initialized successfully")
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
            Log.Notice("New Project clicked (not implemented yet)")
        end)
    end

    -- Open Project button
    local btnOpen = self.mainDocument:GetElementById("btn-open-project")
    if btnOpen then
        btnOpen:AddEventListener("click", function()
            Log.Notice("Open Project clicked (not implemented yet)")
        end)
    end

    -- Save Project button
    local btnSave = self.mainDocument:GetElementById("btn-save-project")
    if btnSave then
        btnSave:AddEventListener("click", function()
            Log.Notice("Save Project clicked (not implemented yet)")
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
    -- Original Chili initialization
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
