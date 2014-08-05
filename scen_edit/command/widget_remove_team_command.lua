WidgetRemoveTeamCommand = AbstractCommand:extends{}

function WidgetRemoveTeamCommand:init(id)
    self.className = "WidgetRemoveTeamCommand"
    self.id = id
end

function WidgetRemoveTeamCommand:execute()
    SCEN_EDIT.model.teamManager:removeTeam(self.id)
end
