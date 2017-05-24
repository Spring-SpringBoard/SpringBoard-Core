WidgetAddTeamCommand = AbstractCommand:extends{}

function WidgetAddTeamCommand:init(id, value)
    self.className = "WidgetAddTeamCommand"
    self.id = id
    self.value = value
end

function WidgetAddTeamCommand:execute()
    SB.model.teamManager:addTeam(self.value, self.id)
end
