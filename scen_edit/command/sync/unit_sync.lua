SB.Include(Path.Join(SB_MODEL_DIR, "unit_manager.lua"))

----------------------------------------------------------
-- Widget callback commands
----------------------------------------------------------
WidgetAddUnitCommand = Command:extends{}

function WidgetAddUnitCommand:init(springId, modelId)
    self.className = "WidgetAddUnitCommand"
    self.springId = springId
    self.modelId = modelId
end

function WidgetAddUnitCommand:execute()
    SB.model.unitManager:addUnit(self.springId, self.modelId)
end
----------------------------------------------------------
----------------------------------------------------------
WidgetRemoveUnitCommand = Command:extends{}

function WidgetRemoveUnitCommand:init(modelId)
    self.className = "WidgetRemoveUnitCommand"
    self.modelId = modelId
end

function WidgetRemoveUnitCommand:execute()
    SB.model.unitManager:removeUnitByModelId(self.modelId)
end
----------------------------------------------------------
-- END Widget callback commands
----------------------------------------------------------

----------------------------------------------------------
-- Widget callback listener
----------------------------------------------------------
if SB.SyncModel then

UnitManagerListenerGadget = UnitManagerListener:extends{}
SB.OnInitialize(function()
    SB.model.unitManager:addListener(UnitManagerListenerGadget())
end)

function UnitManagerListenerGadget:onUnitAdded(unitId, modelId)
    local cmd = WidgetAddUnitCommand(unitId, modelId)
    SB.commandManager:execute(cmd, true)
end

function UnitManagerListenerGadget:onUnitRemoved(unitId, modelId)
    local cmd = WidgetRemoveUnitCommand(modelId)
    SB.commandManager:execute(cmd, true)
end

end
----------------------------------------------------------
-- END Widget callback listener
----------------------------------------------------------
