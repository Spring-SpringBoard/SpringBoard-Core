SB.Include(Path.Join(SB_MODEL_DIR, "team_manager.lua"))

----------------------------------------------------------
-- Widget callback commands
----------------------------------------------------------
WidgetAddTeamCommand = Command:extends{}

function WidgetAddTeamCommand:init(id, value)
    self.className = "WidgetAddTeamCommand"
    self.id = id
    self.value = value
end

function WidgetAddTeamCommand:execute()
    SB.model.teamManager:addTeam(self.value, self.id)
end
----------------------------------------------------------
----------------------------------------------------------
WidgetRemoveTeamCommand = Command:extends{}

function WidgetRemoveTeamCommand:init(id)
    self.className = "WidgetRemoveTeamCommand"
    self.id = id
end

function WidgetRemoveTeamCommand:execute()
    SB.model.teamManager:removeTeam(self.id)
end
----------------------------------------------------------
----------------------------------------------------------
WidgetUpdateTeamCommand = Command:extends{}

function WidgetUpdateTeamCommand:init(teamID, team)
    self.className = "WidgetUpdateTeamCommand"
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
    if team.color then
        return
    end

    -- use our unsynced color
    local r, g, b = Spring.GetTeamColor(teamID)
    team.color = {r=r, g=g, b=b}
    local cmd = UpdateTeamCommand(team)
    cmd.blockUndo = true
    SB.commandManager:execute(cmd)
end

end
----------------------------------------------------------
-- END Widget callback listener
----------------------------------------------------------
