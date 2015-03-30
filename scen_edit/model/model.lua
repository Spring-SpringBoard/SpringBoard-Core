Model = LCS.class{}
SCEN_EDIT_MODEL_DIR = SCEN_EDIT_DIR .. "model/"

function Model:init()
    SCEN_EDIT.IncludeDir(SCEN_EDIT_MODEL_DIR)
    
    self._lua_rules_pre = "scen_edit"

    self.areaManager = AreaManager()
    self.unitManager = UnitManager()
    self.featureManager = FeatureManager()
    self.variableManager = VariableManager()
    self.triggerManager = TriggerManager()
    self.teamManager = TeamManager()
    self.teamManager:generateTeams()
    self.scenarioInfo = ScenarioInfo()
end

--clears all units, areas, triggers, etc.
function Model:Clear()
    self.areaManager:clear()
    self.variableManager:clear()
    self.triggerManager:clear()
    self.teamManager:clear()
	self.scenarioInfo:clear()

    self.unitManager:clear()
    self.featureManager:clear()

    for _, projectileId in pairs(Spring.GetProjectilesInRectangle(0, 0, Game.mapSizeX,  Game.mapSizeZ)) do
        Spring.SetProjectilePosition(projectileId, math.huge, math.huge, math.huge)
        Spring.SetProjectileCollision(projectileId)
    end

    -- TODO: this should be done in a command instead
    SCEN_EDIT.commandManager:clearUndoRedoStack()
end

function Model:Serialize()
    local mission = {}

    mission.meta = self:GetMetaData()
    mission.units = self.unitManager:serialize()
    mission.features = self.featureManager:serialize()

    return mission
end

function Model:Save(fileName)
    local mission = self:Serialize()
    table.save(mission, fileName)
end

function Model:Load(mission)
    self:Clear()

    self.unitManager:load(mission.units)
    self.featureManager:load(mission.features)

    self:SetMetaData(mission.meta)
end

--returns a table that holds triggers, areas and other non-engine content
function Model:GetMetaData()
    return {
        areas = self.areaManager:serialize(),
        triggers = self.triggerManager:serialize(),
        variables = self.variableManager:serialize(),
        teams = self.teamManager:serialize(),
		info = self.scenarioInfo:serialize(),
    }
end

--sets triggers, areas, etc.
function Model:SetMetaData(meta)
    self.areaManager:load(meta.areas)
    self.triggerManager:load(meta.triggers)
    self.variableManager:load(meta.variables)
    self.teamManager:load(meta.teams)
	self.scenarioInfo:load(meta.info)
end
