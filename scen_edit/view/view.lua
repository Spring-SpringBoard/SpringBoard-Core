SB_VIEW_DIR = Path.Join(SB_DIR, "view/")

SB_VIEW_MAIN_WINDOW_DIR = Path.Join(SB_VIEW_DIR, "main_window/")
SB_VIEW_ACTIONS_DIR = Path.Join(SB_VIEW_DIR, "actions/")

SB_VIEW_OBJECT_DIR = Path.Join(SB_VIEW_DIR, "object/")
SB_VIEW_MAP_DIR = Path.Join(SB_VIEW_DIR, "map/")
SB_VIEW_TRIGGER_DIR = Path.Join(SB_VIEW_DIR, "trigger/")
SB_VIEW_GENERAL_DIR = Path.Join(SB_VIEW_DIR, "general/")
SB_VIEW_FLOATING_DIR = Path.Join(SB_VIEW_DIR, "floating/")
SB_VIEW_DIALOG_DIR = Path.Join(SB_VIEW_DIR, "dialog/")

View = LCS.class{}

function View:init()
    SB.IncludeDir(SB_VIEW_DIR)
    SB.Include(Path.Join(SB_VIEW_MAIN_WINDOW_DIR, "main_window_panel.lua"))
    SB.IncludeDir(SB_VIEW_MAIN_WINDOW_DIR)
    SB.IncludeDir(SB_VIEW_ACTIONS_DIR)

    SB.IncludeDir(SB_VIEW_OBJECT_DIR)
    SB.IncludeDir(SB_VIEW_MAP_DIR)
    SB.IncludeDir(SB_VIEW_TRIGGER_DIR)
    SB.IncludeDir(SB_VIEW_GENERAL_DIR)
    SB.IncludeDir(SB_VIEW_FLOATING_DIR)
    SB.IncludeDir(SB_VIEW_DIALOG_DIR)

    self.__visible = true

    SB.clipboard = Clipboard()
    self.areaViews = {}
    self.selectionManager = SelectionManager()
    self.displayDevelop = true
    self.tabbedWindow = TabbedWindow()

    self.modelShaders = ModelShaders()

    self.bottomBar = BottomBar()
    self.teamSelector = TeamSelector()
    self.lobbyButton = LobbyButton()
    self.exitButton = ExitButton()
    self.projectStatus = ProjectStatus()
end

function View:SetVisible(visible)
    if self.__visible == visible then
        return
    end

    self.__visible = visible
    if visible then
        self.tabbedWindow.window:Show()
        self.teamSelector.cmbTeamSelector:Show()
        self.teamSelector.cbLockTeam:Show()
        self.projectStatus.lblProject:Show()
        self.bottomBar.window:Show()
    else
        self.tabbedWindow.window:Hide()
        self.teamSelector.cmbTeamSelector:Hide()
        self.teamSelector.cbLockTeam:Hide()
        self.projectStatus.lblProject:Hide()
        self.bottomBar.window:Hide()
    end
end

function View:Update()
    self.teamSelector:Update()
    self.selectionManager:Update()
    self.projectStatus:Update()

    self.bottomBar:Update()
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
