ScenarioInfo = Observable:extends{}

function ScenarioInfo:init()
    self:super('init')
	local playerName = Spring.GetPlayerInfo(0)
	self.name = playerName .. "'s Scenario"
	self.description = ""
	self.version = "1"
	self.author = playerName
end

function ScenarioInfo:Set(data)
    self.name = data.name or self.name
    self.description = data.description or self.description
	self.version = data.version or self.version
	self.author = data.author or self.author
    self:callListeners("onSet", data)
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
    self:Set(data)
end
------------------------------------------------
-- Listener definition
------------------------------------------------
ScenarioInfoListener = LCS.class.abstract{}

function ScenarioInfoListener:onSet(data)
end
------------------------------------------------
-- End listener definition
------------------------------------------------
