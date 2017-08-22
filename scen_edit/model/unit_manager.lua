UnitManager = Observable:extends{}

function UnitManager:init()
    self:super('init')
    self._s2m = {}
    self._m2s = {}
    self.unitIDCounter = 0
end

function UnitManager:populate()
    if Script.GetName() == "LuaUI" then
        return
    end
    for _, unitID in ipairs(Spring.GetAllUnits()) do
        self:addUnit(unitID)
    end
end

function UnitManager:addUnit(unitID, modelID)
    if self._s2m[unitID] then
        Log.Warning(string.format("%s: Trying to register existing unit. Spring ID: %d Model ID: %d",
            Script.GetName(), unitID, self._s2m[unitID]))
        return
    end
    if modelID ~= nil then
        if self.unitIDCounter < modelID then
            self.unitIDCounter = modelID
        end
    else
        self.unitIDCounter = self.unitIDCounter + 1
        modelID = self.unitIDCounter
    end
    if not self._s2m[unitID] then
        self._s2m[unitID] = modelID
    end
    if not self._m2s[modelID] then
        self._m2s[modelID] = unitID
    end

    self:callListeners("onUnitAdded", unitID, modelID)
    return modelID
end

function UnitManager:removeUnit(unitID)
    if unitID == nil then
        return
    end
    local modelID = self._s2m[unitID]
    if self._s2m[unitID] then
        self._m2s[modelID] = nil
    end
    self._s2m[unitID] = nil

    self:callListeners("onUnitRemoved", unitID, modelID)
end

function UnitManager:removeUnitByModelID(modelID)
    local springID = self._m2s[modelID]
    self:removeUnit(springID)
end

function UnitManager:getSpringUnitID(modelUnitID)
    return self._m2s[modelUnitID]
end

function UnitManager:getModelUnitID(springUnitID)
    return self._s2m[springUnitID]
end

function UnitManager:setUnitModelID(unitID, modelID)
    if self._s2m[unitID] then
        self:removeUnit(unitID)
    end
    if self._m2s[modelID] then
        self:removeUnitByModelID(modelID)
    end
    self:addUnit(unitID, modelID)
end

function UnitManager:getAllUnits()
    local allUnits = {}
    for id, _ in pairs(self._m2s) do
        table.insert(allUnits, id)
    end
    return allUnits
end

function UnitManager:serialize()
    return unitBridge.s11n:Get(Spring.GetAllUnits())
end

function UnitManager:load(units)
    self.unitIDCounter = 0
    unitBridge.s11n:Add(units)
end

function UnitManager:clear()
    for _, unitID in pairs(Spring.GetAllUnits()) do
        Spring.DestroyUnit(unitID, false, true)
        --self:removeUnit(unitID)
    end

    for unitID, _ in pairs(self._s2m) do
        self:removeUnit(unitID)
    end
    self._s2m = {}
    self._m2s = {}
    self.unitIDCounter = 0
end
------------------------------------------------
-- Listener definition
------------------------------------------------
UnitManagerListener = LCS.class.abstract{}

function UnitManagerListener:onUnitAdded(unitID, modelID)
end

function UnitManagerListener:onUnitRemoved(unitID, modelID)
end
------------------------------------------------
-- End listener definition
------------------------------------------------
