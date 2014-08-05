TeamManagerListenerGadget = TeamManagerListener:extends{}

function TeamManagerListenerGadget:init()
end

function TeamManagerListenerGadget:onTeamAdded(teamId)
    local team = SCEN_EDIT.model.teamManager:getTeam(teamId)
    local cmd = WidgetAddTeamCommand(teamId, team)
    SCEN_EDIT.commandManager:execute(cmd, true)
end

function TeamManagerListenerGadget:onTeamRemoved(teamId)
    local cmd = WidgetRemoveTeamCommand(teamId)
    SCEN_EDIT.commandManager:execute(cmd, true)
end

function TeamManagerListenerGadget:onTeamChange(teamId, team)
    local cmd = WidgetUpdateTeamCommand(teamId, team)
    SCEN_EDIT.commandManager:execute(cmd, true)
end
