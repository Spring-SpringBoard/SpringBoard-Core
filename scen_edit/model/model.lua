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
    self.teams = {}
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
        teams = self:SerializeTeams(),
		info = self.scenarioInfo:serialize(),
    }
end

--sets triggers, areas, etc.
function Model:SetMetaData(meta)
    self.areaManager:load(meta.areas)
    self.triggerManager:load(meta.triggers)
    self.variableManager:load(meta.variables)
	self.scenarioInfo:load(meta.info)
    self:LoadTeams(meta.teams)
end

function Model:SerializeTeams()
    local teams = SCEN_EDIT.deepcopy(self.teams)
    for _, team in pairs(teams) do
        team.allies = {}
        for _, team2 in pairs(teams) do
            if Spring.AreTeamsAllied(team.id, team2.id) then
                table.insert(team.allies, team2.id)
            end
        end
    end
    return teams
end

function Model:LoadTeams(teams)
    self.teams = teams
    for _, team in pairs(self.teams) do
        if Spring.SetAlly then
            -- TODO: only change those alliances that are needed
            for _, team2 in pairs(self.teams) do
                if team.id ~= team2.id then
                    Spring.SetAlly(team.allyTeam, team2.allyTeam, false)
                end
            end
            for _, allyTeam2 in pairs(team.allies) do
                Spring.SetAlly(team.allyTeam, allyTeam2, true)
            end
        end
        Spring.SetTeamColor(team.id, team.color.r, team.color.g, team.color.b)
        team.allies = nil
    end
end

function Model:GenerateTeams(widget)
    local teams = SCEN_EDIT.GetTeams(widget)
    self.teams = {}
    for _, team in pairs(teams) do
        self.teams[team.id] = team
    end
end
