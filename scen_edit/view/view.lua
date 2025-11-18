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
    -- Load RmlUi dialogs
    SB.Include(Path.Join(SB.DIRS.SRC, 'view/rmlui_dialogs/base_dialog.lua'))
    SB.Include(Path.Join(SB.DIRS.SRC, 'view/rmlui_dialogs/file_dialog.lua'))
    SB.Include(Path.Join(SB.DIRS.SRC, 'view/rmlui_dialogs/new_project_dialog.lua'))

    -- Load RmlUi editors
    SB.Include(Path.Join(SB.DIRS.SRC, 'view/rmlui_editors/trigger_editor.lua'))
    SB.Include(Path.Join(SB.DIRS.SRC, 'view/rmlui_editors/object_editor.lua'))
    SB.Include(Path.Join(SB.DIRS.SRC, 'view/rmlui_editors/heightmap_editor.lua'))
    SB.Include(Path.Join(SB.DIRS.SRC, 'view/rmlui_editors/texture_editor.lua'))
    SB.Include(Path.Join(SB.DIRS.SRC, 'view/rmlui_editors/water_editor.lua'))
    SB.Include(Path.Join(SB.DIRS.SRC, 'view/rmlui_editors/metal_editor.lua'))
    SB.Include(Path.Join(SB.DIRS.SRC, 'view/rmlui_editors/grass_editor.lua'))
    SB.Include(Path.Join(SB.DIRS.SRC, 'view/rmlui_editors/sky_editor.lua'))
    SB.Include(Path.Join(SB.DIRS.SRC, 'view/rmlui_editors/lighting_editor.lua'))
    SB.Include(Path.Join(SB.DIRS.SRC, 'view/rmlui_editors/terrain_settings_editor.lua'))

    -- Load models (business logic, shared between Chili and RmlUi)
    SB.Include(Path.Join(SB.DIRS.SRC, 'view/models/status_window_model.lua'))
    SB.Include(Path.Join(SB.DIRS.SRC, 'view/models/command_window_model.lua'))
    SB.Include(Path.Join(SB.DIRS.SRC, 'view/models/top_left_menu_model.lua'))
    SB.Include(Path.Join(SB.DIRS.SRC, 'view/models/control_buttons_model.lua'))
    SB.Include(Path.Join(SB.DIRS.SRC, 'view/models/team_selector_model.lua'))
    SB.Include(Path.Join(SB.DIRS.SRC, 'view/models/new_project_dialog_model.lua'))
    SB.Include(Path.Join(SB.DIRS.SRC, 'view/models/heightmap_editor_model.lua'))
    SB.Include(Path.Join(SB.DIRS.SRC, 'view/models/texture_editor_model.lua'))
    SB.Include(Path.Join(SB.DIRS.SRC, 'view/models/water_editor_model.lua'))
    SB.Include(Path.Join(SB.DIRS.SRC, 'view/models/metal_editor_model.lua'))
    SB.Include(Path.Join(SB.DIRS.SRC, 'view/models/grass_editor_model.lua'))
    SB.Include(Path.Join(SB.DIRS.SRC, 'view/models/sky_editor_model.lua'))
    SB.Include(Path.Join(SB.DIRS.SRC, 'view/models/lighting_editor_model.lua'))
    SB.Include(Path.Join(SB.DIRS.SRC, 'view/models/terrain_settings_editor_model.lua'))

    -- Load RmlUi floating windows
    SB.Include(Path.Join(SB.DIRS.SRC, 'view/rmlui_floating/command_window.lua'))
    SB.Include(Path.Join(SB.DIRS.SRC, 'view/rmlui_floating/status_window.lua'))
    SB.Include(Path.Join(SB.DIRS.SRC, 'view/rmlui_floating/control_buttons.lua'))
    SB.Include(Path.Join(SB.DIRS.SRC, 'view/rmlui_floating/top_left_menu.lua'))
    SB.Include(Path.Join(SB.DIRS.SRC, 'view/rmlui_floating/team_selector.lua'))
    SB.Include(Path.Join(SB.DIRS.SRC, 'view/rmlui_floating/bottom_bar.lua'))

    -- Load RmlUi field system (maintains original AddField API - implementation-agnostic!)
    SB.Include(Path.Join(SB.DIRS.SRC, 'view/rmlui_component.lua'))  -- Base class for components
    SB.Include(Path.Join(SB.DIRS.SRC, 'view/rmlui_editor_base.lua'))
    SB.Include(Path.Join(SB.DIRS.SRC, 'view/rmlui_fields.lua'))
    SB.Include(Path.Join(SB.DIRS.SRC, 'view/rmlui_field_compat.lua'))  -- Makes StringField() etc work

    -- Load all other RmlUi components (general, map, object, trigger)
    SB.Include(Path.Join(SB.DIRS.SRC, 'view/rmlui_components.lua'))

    -- Load main UI template
    local rmlPath = Path.Join(SB.DIRS.SRC, 'view/rml/springboard_main.rml')
    self.mainDocument = SB.rmlui:LoadDocument(rmlPath, true)

    if not self.mainDocument then
        Log.Error("Failed to load RmlUi main document")
        self.useRmlUi = false
        self:InitializeChili()
        return
    end

    -- Initialize floating windows (all panels managed by bottom bar)
    self.bottomBar = RmlUiBottomBar()
    self.bottomBar:Initialize()

    -- Keep references for easy access
    self.commandWindow = self.bottomBar.commandWindow
    self.statusWindow = self.bottomBar.statusWindow
    self.controlButtons = self.bottomBar.controlButtons
    self.topLeftMenu = self.bottomBar.topLeftMenu
    self.teamSelector = self.bottomBar.teamSelector

    -- Initialize editors (create instances but don't show)
    self.triggerEditor = RmlUiTriggerEditor()
    self.triggerEditor:Initialize()

    self.objectEditor = RmlUiObjectEditor()
    self.objectEditor:Initialize()

    self.heightmapEditor = RmlUiHeightmapEditor()
    self.heightmapEditor:Initialize()

    self.textureEditor = RmlUiTextureEditor()
    self.textureEditor:Initialize()

    -- Initialize all additional editors (don't show by default)
    self.grassEditor = RmlUiGrassEditor()
    self.grassEditor:Initialize()

    self.metalEditor = RmlUiMetalEditor()
    self.metalEditor:Initialize()

    self.waterEditor = RmlUiWaterEditor()
    self.waterEditor:Initialize()

    self.lightingEditor = RmlUiLightingEditor()
    self.lightingEditor:Initialize()

    self.skyEditor = RmlUiSkyEditor()
    self.skyEditor:Initialize()

    self.terrainSettingsEditor = RmlUiTerrainSettingsEditor()
    self.terrainSettingsEditor:Initialize()

    self.dntsEditor = RmlUiDNTSEditor()
    self.dntsEditor:Initialize()

    self.materialBrowser = RmlUiMaterialBrowser()
    self.materialBrowser:Initialize()

    -- Initialize general windows
    self.scenarioInfoView = RmlUiScenarioInfoView()
    self.scenarioInfoView:Initialize()

    self.diplomacyWindow = RmlUiDiplomacyWindow()
    self.diplomacyWindow:Initialize()

    self.playersWindow = RmlUiPlayersWindow()
    self.playersWindow:Initialize()

    -- Setup event handlers
    self:SetupRmlUiEvents()

    Log.Notice("RmlUi UI initialized successfully with all dialogs, editors, and floating windows")
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
    else
        -- RmlUi updates
        if self.bottomBar then
            self.bottomBar:Update()
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
