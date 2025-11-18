RmlUiTeamSelector = LCS.class{}

function RmlUiTeamSelector:init()
    self.rmlPath = Path.Join(SB.DIRS.SRC, 'view/rml/floating/team_selector.rml')
    SB.lockTeam = false
end

function RmlUiTeamSelector:Initialize()
    self.document = SB.rmlui:LoadDocument(self.rmlPath, false)
    self:BindEvents()
    self:PopulateTeams()
    SB.model.teamManager:addListener(self)
    Log.Notice("Team Selector initialized (RmlUi)")
    return true
end

function RmlUiTeamSelector:BindEvents()
    local teamDropdown = self.document:GetElementById("team-dropdown")
    if teamDropdown then
        teamDropdown:AddEventListener("change", function()
            self:OnTeamChanged()
        end)
    end

    local lockCheckbox = self.document:GetElementById("lock-team-checkbox")
    if lockCheckbox then
        lockCheckbox:AddEventListener("change", function()
            SB.lockTeam = lockCheckbox.checked
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

function RmlUiTeamSelector:PopulateTeams()
    local teamDropdown = self.document:GetElementById("team-dropdown")
    if not teamDropdown then return end

    -- Clear existing options
    teamDropdown.inner_rml = ""

    self.teamIDs = {}
    local teams = SB.model.teamManager:getAllTeams()

    for _, team in pairs(teams) do
        if not team.gaia then
            local option = self.document:CreateElement("option")
            local teamCaption = "Team " .. team.name
            -- Note: RmlUi doesn't support inline color codes like Chili,
            -- so we'll just use plain text for now
            option.inner_rml = teamCaption
            option:SetAttribute("value", tostring(team.id))
            teamDropdown:AppendChild(option)
            table.insert(self.teamIDs, team.id)
        end
    end

    -- Add spectator option
    local spectatorOption = self.document:CreateElement("option")
    spectatorOption.inner_rml = "Spectator"
    spectatorOption:SetAttribute("value", "spectator")
    teamDropdown:AppendChild(spectatorOption)
end

function RmlUiTeamSelector:OnTeamChanged()
    local teamDropdown = self.document:GetElementById("team-dropdown")
    if not teamDropdown then return end

    local selectedIndex = teamDropdown.selection
    local selectedValue = teamDropdown:GetAttribute("value")

    if selectedValue == "spectator" then
        if not Spring.GetSpectatingState() then
            Spring.SendCommands("spectator")
        end
    else
        local teamID = tonumber(selectedValue)
        if teamID and (Spring.GetMyTeamID() ~= teamID or Spring.GetSpectatingState()) then
            if SB.FunctionExists(Spring.AssignPlayerToTeam, "Player change") then
                local cmd = ChangePlayerTeamCommand(Spring.GetMyPlayerID(), teamID)
                SB.commandManager:execute(cmd)
            end
        end
    end
end

function RmlUiTeamSelector:onTeamAdded(teamID)
    self:PopulateTeams()
end

function RmlUiTeamSelector:onTeamRemoved(teamID)
    self:PopulateTeams()
end

function RmlUiTeamSelector:onTeamChange(teamID, team)
    self:PopulateTeams()
end

function RmlUiTeamSelector:Update()
    local teamDropdown = self.document:GetElementById("team-dropdown")
    if not teamDropdown then return end

    -- Update selection to match current team
    if not Spring.GetSpectatingState() then
        local myTeamID = Spring.GetMyTeamID()
        for i, teamID in ipairs(self.teamIDs) do
            if teamID == myTeamID then
                teamDropdown.selection = i - 1  -- 0-indexed
                return
            end
        end
    else
        -- Set to spectator (last option)
        teamDropdown.selection = #self.teamIDs  -- spectator is after all teams
    end
end
