TeamManagerListenerGadget = TeamManagerListener:extends{}

function TeamManagerListenerGadget:init()
end

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
