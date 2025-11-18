TeamSelectorModel = LCS.class{}

function TeamSelectorModel:init()
    SB.lockTeam = false
    self.teamIDs = {}
    self.teamCaptions = {}
    self.listeners = {}
end

function TeamSelectorModel:Initialize()
    self:PopulateTeams()
    SB.model.teamManager:addListener(self)
end

function TeamSelectorModel:AddListener(listener)
    table.insert(self.listeners, listener)
end

function TeamSelectorModel:NotifyListeners(event, ...)
    for _, listener in ipairs(self.listeners) do
        if listener[event] then
            listener[event](listener, ...)
        end
    end
end

function TeamSelectorModel:PopulateTeams()
    self.teamIDs = {}
    self.teamCaptions = {}

    for _, team in pairs(SB.model.teamManager:getAllTeams()) do
        if not team.gaia then
            local teamCaption = "Team " .. team.name
            if team.color then
                teamCaption = SB.glToFontColor(team.color) .. teamCaption .. "\b"
            end
            table.insert(self.teamCaptions, teamCaption)
            table.insert(self.teamIDs, team.id)
        end
    end
    table.insert(self.teamCaptions, "Spectator")

    self:NotifyListeners("OnTeamsPopulated", self.teamIDs, self.teamCaptions)
end

function TeamSelectorModel:OnTeamSelected(itemIdx)
    if itemIdx <= #self.teamIDs then
        local teamID = self.teamIDs[itemIdx]
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

function TeamSelectorModel:onTeamAdded(teamID)
    self:PopulateTeams()
end

function TeamSelectorModel:onTeamRemoved(teamID)
    self:PopulateTeams()
end

function TeamSelectorModel:onTeamChange(teamID, team)
    self:PopulateTeams()
end

function TeamSelectorModel:GetCurrentSelection()
    -- Returns the index that should be selected
    if not Spring.GetSpectatingState() then
        local myTeamID = Spring.GetMyTeamID()
        for i, teamID in pairs(self.teamIDs) do
            if teamID == myTeamID then
                return i
            end
        end
    end
    -- Spectator is the last item
    return #self.teamCaptions
end

function TeamSelectorModel:GetTeamIDs()
    return self.teamIDs
end

function TeamSelectorModel:GetTeamCaptions()
    return self.teamCaptions
end

function TeamSelectorModel:SetLockTeam(locked)
    SB.lockTeam = locked
end

function TeamSelectorModel:GetLockTeam()
    return SB.lockTeam
end
