RmlUiBottomBar = LCS.class{}

function RmlUiBottomBar:init()
    self.commandWindow = RmlUiCommandWindow()
    self.statusWindow = RmlUiStatusWindow()
    self.topLeftMenu = RmlUiTopLeftMenu()
    self.controlButtons = RmlUiControlButtons()
    self.teamSelector = RmlUiTeamSelector()
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
