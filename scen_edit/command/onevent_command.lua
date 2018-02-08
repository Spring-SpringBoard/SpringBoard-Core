OnEventCommand = Command:extends{}
OnEventCommand.className = "OnEventCommand"

function OnEventCommand:init(eventName, params)
    self.className = "OnEventCommand"
    self.eventName = eventName
    self.params = params
end

function OnEventCommand:execute()
    SB.rtModel:OnEvent(self.eventName, self.params)
end
