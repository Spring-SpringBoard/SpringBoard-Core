Model = LCS.class{}
SCEN_EDIT_MODEL_DIR = SCEN_EDIT_DIR .. "model/"

function Model:init()
    SCEN_EDIT.IncludeDir(SCEN_EDIT_MODEL_DIR)
    
    self.teams = {}    
    self._lua_rules_pre = "scen_edit"

    self.areaManager = AreaManager()
    self.unitManager = UnitManager()
    self.featureManager = FeatureManager()
    self.variableManager = VariableManager()
    self.triggerManager = TriggerManager()
	self.scenarioInfo = ScenarioInfo()
    self:GenerateTeams()
end

--clears all units, areas, triggers, etc.
function Model:Clear()
    self.areaManager:clear()
    self.variableManager:clear()
    self.triggerManager:clear()
    self.featureManager:clear()
	self.scenarioInfo:clear()
    --self.teams = {}
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
        Spring.SetUnitRotation(unitId, 0, -unit.angle * math.pi / 180, 0)
        self.unitManager:setUnitModelId(unitId, unit.id)
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
        local prop = math.tan(feature.angle / 180 * math.pi)
        local z = math.sqrt(1 / (prop * prop + 1))
        local x = prop * z
        feature.angle = math.abs(feature.angle % 360)
        if feature.angle >= 90 and feature.angle < 180 then
            x = -x
            z = -z
        elseif feature.angle >= 180 and feature.angle < 270 then
            x = -x
            z = -z
        end
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
        teams = self.teams,
		info = self.scenarioInfo:serialize(),
    }
end

--sets triggers, areas, etc.
function Model:SetMetaData(meta)
    self.areaManager:load(meta.areas)
    self.triggerManager:load(meta.triggers)
    self.variableManager:load(meta.variables)
	self.scenarioInfo:load(meta.info)
    --self.teams = meta.teams or {}
end

function Model:GenerateTeams(widget)
    local names, ids, colors = SCEN_EDIT.GetTeams(widget)
    for i = 1, #ids do
        local id = ids[i]
        local name = names[i]
        local color = colors[i]
        
        self.teams[id] = {
            name = name,
            id = id,
            color = color,
        }
    end
end
