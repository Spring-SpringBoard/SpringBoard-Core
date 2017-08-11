TeamSelector = LCS.class{}

function TeamSelector:init()
    self:PopulateTeams()

    SB.lockTeam = false
    self.cbLockTeam = Checkbox:New {
        parent = screen0,
        right = 501 + 10,
        width = 90,
        y = 45,
        height = 20,
        caption = "Lock team",
        checked = false,
        OnChange = { function(_, value)
            SB.lockTeam = value
        end}
    }

    SB.model.teamManager:addListener(self)
end

function TeamSelector:PopulateTeams()
    local teamIDs = {}
    local teamCaptions = {}
    for _, team in pairs(SB.model.teamManager:getAllTeams()) do
        if not team.gaia then
            local teamCaption = "Team " .. team.name
            if team.color then
                teamCaption = SB.glToFontColor(team.color) .. teamCaption .. "\b"
            end
            table.insert(teamCaptions, teamCaption)
            table.insert(teamIDs, team.id)
        end
    end
    table.insert(teamCaptions, "Spectator")
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
            if itemIdx <= #teamIDs then
                local teamID = teamIDs[itemIdx]
                if Spring.GetMyTeamID() ~= teamID or Spring.GetSpectatingState() then
                    if SB.FunctionExists(Spring.AssignPlayerToTeam, "Player change") then
                        local cmd = ChangePlayerTeamCommand(Spring.GetMyPlayerID(), teamID)
                        SB.commandManager:execute(cmd)
                    end
                end
            else
                if not Spring.GetSpectatingState() then
                    Spring.SendCommands("spectator")
                end
            end
        end
    }
end

function TeamSelector:onTeamAdded(teamID)
    self:PopulateTeams()
end

function TeamSelector:onTeamRemoved(teamID)
    self:PopulateTeams()
end

function TeamSelector:onTeamChange(teamID, team)
    self:PopulateTeams()
end

function TeamSelector:Update()
    local selectedTeamID = self.cmbTeamSelector.teamIDs[self.cmbTeamSelector.selected]
    if not Spring.GetSpectatingState() and Spring.GetMyTeamID() ~= selectedTeamID then
        local OnSelect = self.cmbTeamSelector.OnSelect
        self.cmbTeamSelector.OnSelect = nil
        for i, teamID in pairs(self.cmbTeamSelector.teamIDs) do
            if teamID == Spring.GetMyTeamID() then
                self.cmbTeamSelector:Select(i)
                break
            end
        end
        self.cmbTeamSelector.OnSelect = OnSelect
    elseif Spring.GetSpectatingState() and selectedTeamID ~= nil then
        local OnSelect = self.cmbTeamSelector.OnSelect
        self.cmbTeamSelector.OnSelect = nil
        self.cmbTeamSelector:Select(#self.cmbTeamSelector.items)
        self.cmbTeamSelector.OnSelect = OnSelect
    end
end
