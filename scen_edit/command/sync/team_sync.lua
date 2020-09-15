SB.Include(Path.Join(SB.DIRS.SRC, 'model/team_manager.lua'))

----------------------------------------------------------
-- Widget callback commands
----------------------------------------------------------
WidgetAddTeamCommand = Command:extends{}
WidgetAddTeamCommand.className = "WidgetAddTeamCommand"

function WidgetAddTeamCommand:init(id, value)
    self.id = id
    self.value = value
end

function WidgetAddTeamCommand:execute()
    SB.model.teamManager:addTeam(self.value, self.id)
end
----------------------------------------------------------
----------------------------------------------------------
WidgetRemoveTeamCommand = Command:extends{}
WidgetRemoveTeamCommand.className = "WidgetRemoveTeamCommand"

function WidgetRemoveTeamCommand:init(id)
    self.id = id
end

function WidgetRemoveTeamCommand:execute()
    SB.model.teamManager:removeTeam(self.id)
end
----------------------------------------------------------
----------------------------------------------------------
WidgetUpdateTeamCommand = Command:extends{}
WidgetUpdateTeamCommand.className = "WidgetUpdateTeamCommand"

function WidgetUpdateTeamCommand:init(teamID, team)
    self.teamID = teamID
    self.team = team
end

function WidgetUpdateTeamCommand:execute()
    SB.model.teamManager:setTeam(self.teamID, self.team)
end
----------------------------------------------------------
-- END Widget callback commands
----------------------------------------------------------

----------------------------------------------------------
-- Widget callback listener
----------------------------------------------------------
if SB.SyncModel then

TeamManagerListenerGadget = TeamManagerListener:extends{}
SB.OnInitialize(function()
    SB.model.teamManager:addListener(TeamManagerListenerGadget())
end)

function TeamManagerListenerGadget:onTeamAdded(teamID)
    local team = SB.model.teamManager:getTeam(teamID)
    local cmd = WidgetAddTeamCommand(teamID, team)
    SB.commandManager:execute(cmd, true)
end

function TeamManagerListenerGadget:onTeamRemoved(teamID)
    local cmd = WidgetRemoveTeamCommand(teamID)
    SB.commandManager:execute(cmd, true)
end

function TeamManagerListenerGadget:onTeamChange(teamID, team)
    local cmd = WidgetUpdateTeamCommand(teamID, team)
    SB.commandManager:execute(cmd, true)
end

else -- UNSYNCED

TeamManagerListenerWidget = TeamManagerListener:extends{}
SB.OnInitialize(function()
    SB.model.teamManager:addListener(TeamManagerListenerWidget())
end)

function TeamManagerListenerWidget:onTeamAdded(teamID)
    local team = SB.model.teamManager:getTeam(teamID)
    -- Generate values from unsynced only once
    if team.color then
        return
    end

    -- Setup the team names from unsynced side (Apparently those makes more
    -- sense than synced ones).
    local aiID, name = Spring.GetAIInfo(teamID)
    if aiID ~= nil then
        team.name = teamID .. "  " .. name
    elseif teamID == Spring.GetGaiaTeamID() then
        -- Force the name for GAIA team
        team.name = "GAIA"

    -- Using leader info seems like a sure way to get duplicate team names
    -- This is bad as it would result in invalid start scripts
    -- else
    --     local _, leader = Spring.GetTeamInfo(teamID)
    --     if Spring.GetPlayerInfo(leader) then
    --         team.name = Spring.GetPlayerInfo(leader)
    --     end
    else
        team.name = 'Team ' .. tostring(teamID)
    end

    -- use our unsynced color
    local r, g, b = Spring.GetTeamColor(teamID)
    team.color = {r=r, g=g, b=b}
    local cmd = UpdateTeamCommand(team, true)
    cmd.blockUndo = true
    SB.commandManager:execute(cmd)
end

end
----------------------------------------------------------
-- END Widget callback listener
----------------------------------------------------------
