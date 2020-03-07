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

    self.__visible = true

    SB.clipboard = Clipboard()
    self.areaViews = {}
    self.selectionManager = SelectionManager()
    self.displayDevelop = true
    self.tabbedWindow = TabbedWindow()

    self.modelShaders = ModelShaders()

    self.bottomBar = BottomBar()
    self.teamSelector = TeamSelector()
    self.topLeftMenu = TopLeftMenu()
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
        self.topLeftMenu:Show()
        self.bottomBar.window:Show()
    else
        self.tabbedWindow.window:Hide()
        self.teamSelector.cmbTeamSelector:Hide()
        self.teamSelector.cbLockTeam:Hide()
        self.topLeftMenu:Hide()
        self.bottomBar.window:Hide()
    end
    if WG.DevConsole then
        WG.DevConsole.SetVisibility(visible)
    end
end

function View:Update()
    self.teamSelector:Update()
    self.selectionManager:Update()
    self.topLeftMenu:Update()

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
