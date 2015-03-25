ScenarioInfo = Observable:extends{}

function ScenarioInfo:init()
    self:super('init')
	local playerName = Spring.GetPlayerInfo(0)
	self.name = playerName .. "'s Scenario"
	self.description = ""
	self.version = "1"
	self.author = playerName
end

function ScenarioInfo:Set(name, description, version, author)
	self.name = name
	self.description = description
	self.version = version
	self.author = author 
    self:callListeners("onSet", self.name, self.description, self.version, self.author)
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
    self:Set(data.name,	data.description, data.version,	data.author)
end
