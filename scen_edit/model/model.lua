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
    self.featureManager:clear()
	self.scenarioInfo:clear()
    local allUnits = Spring.GetAllUnits()
    for i = 1, #allUnits do
        local unitId = allUnits[i]
        Spring.DestroyUnit(unitId, false, true)
--        self.unitManager:removeUnit(unitId)
    end
    local allFeatures = Spring.GetAllFeatures()
    for i = 1, #allFeatures do
        local featureId = allFeatures[i]
        Spring.DestroyFeature(featureId, false, true)
--        self.featureManager:RemoveFeature(featureId)
    end
    for _, projectileId in pairs(Spring.GetProjectilesInRectangle(0, 0, Game.mapSizeX,  Game.mapSizeZ)) do
        Spring.SetProjectilePosition(projectileId, math.huge, math.huge, math.huge)
        Spring.SetProjectileCollision(projectileId)
    end
    SCEN_EDIT.commandManager:clearUndoRedoStack()
end

function Model:Serialize()
    local mission = {}
    mission.meta = self:GetMetaData()
    mission.meta.m2sUnitIdMapping = nil
    mission.meta.s2mUnitIdMapping = nil
    mission.units = {}
    
    local allUnits = Spring.GetAllUnits()
    for i = 1, #allUnits do
        local unit = {}
        local unitId = allUnits[i]
        local unitDefId = Spring.GetUnitDefID(unitId)
        unit.unitDefName = UnitDefs[unitDefId].name
        unit.x, _, unit.y = Spring.GetUnitPosition(unitId)
        unit.player = Spring.GetUnitTeam(unitId)
        unit.id = self.unitManager:getModelUnitId(unitId)
        local dirX, dirY, dirZ = Spring.GetUnitDirection(unitId)
        unit.angle = math.atan2(dirX, dirZ) * 180 / math.pi

        table.insert(mission.units, unit)
    end

    mission.features = {}

    local allFeatures = Spring.GetAllFeatures()
    for i = 1, #allFeatures do
        local feature = {}
        local featureId = allFeatures[i]
        local featureDefId = Spring.GetFeatureDefID(featureId)
        feature.featureDefName = FeatureDefs[featureDefId].name
        feature.x, _, feature.y = Spring.GetFeaturePosition(featureId)
        feature.player = Spring.GetFeatureTeam(featureId)
        feature.id = self.featureManager:getModelFeatureId(featureId)
        local dirX, dirY, dirZ = Spring.GetFeatureDirection(featureId)
        feature.angle = math.atan2(dirX, dirZ) * 180 / math.pi

        table.insert(mission.features, feature)
    end
    return mission
end

function Model:Save(fileName)
    local mission = self:Serialize()
    table.save(mission, fileName)
end

function Model:Load(mission)
    self:Clear()
    
    --load units
    local units = mission.units
    self._unitIdCounter = 0
    for i, unit in pairs(units) do		
        local unitId = Spring.CreateUnit(unit.unitDefName, unit.x, 0, unit.y, 0, unit.player)
		if unitId ~= nil then			
            local x = math.sin(math.rad(unit.angle))
            local z = math.cos(math.rad(unit.angle))
            Spring.SetUnitDirection(unitId, x, 0, z)
			self.unitManager:setUnitModelId(unitId, unit.id)
		else
			Spring.Echo("Failed to create the following unit: ")
			table.echo(unit)
		end
--        self:AddUnit(unit.unitDefName, unit.x, 0, unit.y, unit.player,
--            function (unitId)                
--                if self.s2mUnitIdMapping[unitId] then
--                    self.m2sUnitIdMapping[self.s2mUnitIdMapping[unitId]] = nil
--                end                
--                self.s2mUnitIdMapping[unitId] = unit.id
--                self.m2sUnitIdMapping[unit.id] = unitId
--            end
--        )
--        if unit.id > self._unitIdCounter then
--            self._unitIdCounter = unit.id
--        end--]]
    end
    local features = mission.features
    for i, feature in pairs(features) do
        local featureId = Spring.CreateFeature(feature.featureDefName, feature.x, 0, feature.y, feature.player)
        local x = math.sin(math.rad(feature.angle))
        local z = math.cos(math.rad(feature.angle))
        Spring.SetFeatureDirection(featureId, x, 0, z)
        SCEN_EDIT.model.featureManager:setFeatureModelId(featureId, feature.id)
    end

    --load file
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
