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

function WidgetUpdateTeamCommand:init(teamId, team)
    self.className = "WidgetUpdateTeamCommand"
    self.teamId = teamId
    self.team = team
end

function WidgetUpdateTeamCommand:execute()
    SB.model.teamManager:setTeam(self.teamId, self.team)
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

function TeamManagerListenerGadget:onTeamAdded(teamId)
    local team = SB.model.teamManager:getTeam(teamId)
    local cmd = WidgetAddTeamCommand(teamId, team)
    SB.commandManager:execute(cmd, true)
end

function TeamManagerListenerGadget:onTeamRemoved(teamId)
    local cmd = WidgetRemoveTeamCommand(teamId)
    SB.commandManager:execute(cmd, true)
end

function TeamManagerListenerGadget:onTeamChange(teamId, team)
    local cmd = WidgetUpdateTeamCommand(teamId, team)
    SB.commandManager:execute(cmd, true)
end

end
----------------------------------------------------------
-- END Widget callback listener
----------------------------------------------------------
