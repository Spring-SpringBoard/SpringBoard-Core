SetUnitPropertyCommand = Command:extends{}
SetUnitPropertyCommand.className = "SetUnitPropertyCommand"

function SetUnitPropertyCommand:init(modelUnitId, key, value)
    self.className = "SetUnitPropertyCommand"
    self.modelUnitId = modelUnitId
    self.key = key
    self.value = value
end

function SetUnitPropertyCommand:execute()
    local unitId = SB.model.unitManager:getSpringUnitId(self.modelUnitId)

    if self.key == "health" then
        self.oldUnitHealth = Spring.GetUnitHealth(unitId)
        Spring.SetUnitHealth(unitId, self.value)
    elseif self.key == "maxhealth" then
        _, self.oldMaxHealth = Spring.GetUnitHealth(unitId)
        Spring.SetUnitMaxHealth(unitId, self.value)
    elseif self.key == "tooltip" then
        self.oldTooltip = Spring.GetUnitTooltip(unitId)
        Spring.SetUnitTooltip(unitId, self.value)
    elseif self.key == "stockpile" then
        self.oldStockpile = Spring.GetUnitStockpile(unitId)
        Spring.SetUnitStockpile(unitId, self.value)
    elseif self.key == "experience" then
        self.oldExperience = Spring.GetUnitExperience(unitId)
        Spring.SetUnitExperience(unitId, self.value)
    elseif self.key == "fuel" then
        self.oldFuel = Spring.GetUnitFuel(unitId)
        Spring.SetUnitFuel(unitId, self.value)
    elseif self.key == "rule" then
        self.oldRule = Spring.GetUnitRulesParam(unitId, self.value[1])
        Spring.SetUnitRulesParam(unitId, self.value[1], self.value[2])
    -- FIXME: no way to check if movectrl/gravity is already set
    elseif self.key == "gravity" then
        Spring.MoveCtrl.Enable(unitId, true)
        Spring.MoveCtrl.SetGravity(unitId, self.value)
    end
end

function SetUnitPropertyCommand:unexecute()
    local unitId = SB.model.unitManager:getSpringUnitId(self.modelUnitId)

    if self.key == "health" then
        Spring.SetUnitHealth(unitId, self.oldUnitHealth)
    elseif self.key == "maxhealth" then
        Spring.SetUnitMaxHealth(unitId, self.oldMaxHealth)
    elseif self.key == "tooltip" then
        Spring.SetUnitTooltip(unitId, self.oldTooltip)
    elseif self.key == "stockpile" then
        Spring.SetUnitStockpile(unitId, self.oldStockpile)
    elseif self.key == "experience" then
        Spring.SetUnitExperience(unitId, self.oldExperience)
    elseif self.key == "fuel" then
        Spring.SetUnitFuel(unitId, self.oldFuel)
    -- TODO: rule
    -- FIXME: no way to check if movectrl/gravity is already set
    elseif self.key == "gravity" then
--         Spring.MoveCtrl.Enable(unitId, true)
--         Spring.MoveCtrl.SetGravity(unitId, self.value)
    end
end
