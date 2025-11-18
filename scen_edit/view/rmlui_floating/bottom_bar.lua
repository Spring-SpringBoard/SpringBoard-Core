RmlUiBottomBar = LCS.class{}

function RmlUiBottomBar:init(models)
    -- Create or use provided models
    self.models = models or {
        statusWindow = StatusWindowModel(),
        commandWindow = CommandWindowModel(),
        topLeftMenu = TopLeftMenuModel(),
        controlButtons = ControlButtonsModel(),
        teamSelector = TeamSelectorModel(),
    }

    -- Create UI components with models
    self.commandWindow = RmlUiCommandWindow(self.models.commandWindow)
    self.statusWindow = RmlUiStatusWindow(self.models.statusWindow)
    self.topLeftMenu = RmlUiTopLeftMenu(self.models.topLeftMenu)
    self.controlButtons = RmlUiControlButtons(self.models.controlButtons)
    self.teamSelector = RmlUiTeamSelector(self.models.teamSelector)
end

function RmlUiBottomBar:Initialize()
    self.commandWindow:Initialize()
    self.statusWindow:Initialize()
    self.topLeftMenu:Initialize()
    self.controlButtons:Initialize()
    self.teamSelector:Initialize()

    self:Show()
    Log.Notice("Bottom Bar initialized (RmlUi)")
    return true
end

function RmlUiBottomBar:Show()
    self.commandWindow:Show()
    self.statusWindow:Show()
    self.topLeftMenu:Show()
    self.controlButtons:Show()
    self.teamSelector:Show()
end

function RmlUiBottomBar:Hide()
    self.commandWindow:Hide()
    self.statusWindow:Hide()
    self.topLeftMenu:Hide()
    self.controlButtons:Hide()
    self.teamSelector:Hide()
end

function RmlUiBottomBar:Update()
    self.statusWindow:Update()
    self.topLeftMenu:Update()
    self.teamSelector:Update()
end
