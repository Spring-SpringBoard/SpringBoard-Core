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
    local teamDropdown = self.document:GetElementById("team-dropdown")
    if teamDropdown then
        teamDropdown:AddEventListener("change", function()
            local selectedIndex = teamDropdown.selection + 1  -- Convert from 0-based to 1-based
            self.model:OnTeamSelected(selectedIndex)
        end)
    end

    local lockCheckbox = self.document:GetElementById("lock-team-checkbox")
    if lockCheckbox then
        lockCheckbox:AddEventListener("change", function()
            self.model:SetLockTeam(lockCheckbox.checked)
        end)
    end
end

function RmlUiTeamSelector:Show()
    if self.document then
        self.document:Show()
    end
end

function RmlUiTeamSelector:Hide()
    if self.document then
        self.document:Hide()
    end
end

function RmlUiTeamSelector:Update()
    local teamDropdown = self.document:GetElementById("team-dropdown")
    if not teamDropdown then return end

    -- Update selection to match current team
    local currentSelection = self.model:GetCurrentSelection()
    teamDropdown.selection = currentSelection - 1  -- Convert from 1-based to 0-based
end

-- Model callbacks
function RmlUiTeamSelector:OnTeamsPopulated(teamIDs, teamCaptions)
    local teamDropdown = self.document:GetElementById("team-dropdown")
    if not teamDropdown then return end

    -- Clear existing options
    teamDropdown.inner_rml = ""

    for _, teamCaption in ipairs(teamCaptions) do
        local option = self.document:CreateElement("option")
        -- Note: RmlUi doesn't support inline color codes like Chili,
        -- so we strip them for now
        local plainCaption = teamCaption:gsub("\255%d+%d+%d+", ""):gsub("\\b", "")
        option.inner_rml = plainCaption
        teamDropdown:AppendChild(option)
    end

    self:Update()
end
