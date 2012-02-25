local Chili
Chili = WG.Chili
local C_HEIGHT = 16
local B_HEIGHT = 26

TeamPanel = {
}

function TeamPanel:New(obj)
    obj = obj or {}
    setmetatable(obj, self)
    self.__index = self
    obj:Initialize()
    return obj
end

function TeamPanel:Initialize()
    local stackTeamPanel = MakeComponentPanel(self.parent)
    self.cbPredefinedTeam = Chili.Checkbox:New {
        caption = "Predefined team: ",
        right = 100 + 10,
        x = 1,
        checked = true,
        parent = stackTeamPanel,
    }
    local playerNames, playerTeamIds = GetTeams()
    self.cmbPredefinedTeam = ComboBox:New {
        right = 1,
        width = 100,
        height = B_HEIGHT,
        parent = stackTeamPanel,
        items = playerNames,
        playerTeamIds = playerTeamIds,
    }
end

function TeamPanel:UpdateModel(team)
    if self.cbPredefinedTeam.checked then
        team.type = "predefined"
        team.id = self.cmbPredefinedTeam.selected
    end
end

function TeamPanel:UpdatePanel(team)
    if team.type == "predefined" then
        if not self.cbPredefinedTeam.checked then
            self.cbPredefinedTeam:Toggle()
        end
        self.cmbPredefinedTeam:Select(team.id)
    end
end
