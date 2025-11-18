RmlUiTeamSelector = LCS.class{}

function RmlUiTeamSelector:init(model)
    self.rmlPath = Path.Join(SB.DIRS.SRC, 'view/rml/floating/team_selector.rml')
    self.model = model or TeamSelectorModel()
end

function RmlUiTeamSelector:Initialize()
    self.document = SB.rmlui:LoadDocument(self.rmlPath, false)
    self:BindEvents()
    self.model:AddListener(self)
    self.model:Initialize()
    Log.Notice("Team Selector initialized (RmlUi)")
    return true
end

function RmlUiTeamSelector:BindEvents()
    self.document:GetElementById("team-dropdown"):AddEventListener("change", function(event)
        local selectedIndex = event.current_target.selection + 1
        self.model:OnTeamSelected(selectedIndex)
    end)
    self.document:GetElementById("lock-team-checkbox"):AddEventListener("change", function(event)
        self.model:SetLockTeam(event.current_target.checked)
    end)
end

function RmlUiTeamSelector:Show()
    self.document:Show()
end

function RmlUiTeamSelector:Hide()
    self.document:Hide()
end

function RmlUiTeamSelector:Update()
    local teamDropdown = self.document:GetElementById("team-dropdown")
    local currentSelection = self.model:GetCurrentSelection()
    teamDropdown.selection = currentSelection - 1
end

-- Model callbacks
function RmlUiTeamSelector:OnTeamsPopulated(teamIDs, teamCaptions)
    local teamDropdown = self.document:GetElementById("team-dropdown")
    teamDropdown.inner_rml = ""

    for _, teamCaption in ipairs(teamCaptions) do
        local option = self.document:CreateElement("option")
        local plainCaption = teamCaption:gsub("\255%d+%d+%d+", ""):gsub("\\b", "")
        option.inner_rml = plainCaption
        teamDropdown:AppendChild(option)
    end

    self:Update()
end
