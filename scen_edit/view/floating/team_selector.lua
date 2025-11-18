TeamSelector = LCS.class{}

function TeamSelector:init(model)
    self.model = model or TeamSelectorModel()

    self.cbLockTeam = Checkbox:New {
        parent = screen0,
        right = 501 + 10,
        width = 90,
        y = 45,
        height = 20,
        caption = "Lock team",
        checked = false,
        OnChange = { function(_, value)
            self.model:SetLockTeam(value)
        end}
    }

    self.model:AddListener(self)
    self.model:Initialize()
end

function TeamSelector:Update()
    local currentSelection = self.model:GetCurrentSelection()
    local OnSelect = self.cmbTeamSelector.OnSelect
    self.cmbTeamSelector.OnSelect = nil
    self.cmbTeamSelector:Select(currentSelection)
    self.cmbTeamSelector.OnSelect = OnSelect
end

-- Model callbacks
function TeamSelector:OnTeamsPopulated(teamIDs, teamCaptions)
    if self.cmbTeamSelector then
        self.cmbTeamSelector:Dispose()
    end

    self.cmbTeamSelector = ComboBox:New {
        parent = screen0,
        right = 501,
        y = 5,
        width = 200,
        height = 40,
        items = teamCaptions,
        font = { size = 16 },
        teamIDs = teamIDs,
    }
    self.cmbTeamSelector.OnSelect = {
        function(_, itemIdx)
            self.model:OnTeamSelected(itemIdx)
        end
    }
end
