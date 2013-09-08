ScenarioInfo = Observable:extends{}

function ScenarioInfo:init()
	local playerName = Spring.GetPlayerInfo(0)
	self.name = playerName .. "'s Scenario"
	self.description = ""
	self.version = "1"
	self.author = playerName
end

function ScenarioInfo:clear()
	self.name = ""
	self.description = ""
	self.version = "1"	
	self.author = ""
end

function ScenarioInfo:serialize()
	return {
		name = self.name,
		description = self.description,
		version = self.version,
		author = self.author
	}
end

function ScenarioInfo:load(data)
    self:clear()
    self.name = data.name
	self.description = data.description
	self.version = data.version
	self.author = data.author
end