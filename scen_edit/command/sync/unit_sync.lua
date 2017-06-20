SB.Include(Path.Join(SB_MODEL_DIR, "unit_manager.lua"))

----------------------------------------------------------
-- Widget callback commands
----------------------------------------------------------
WidgetAddUnitCommand = Command:extends{}

function WidgetAddUnitCommand:init(springID, modelID)
    self.className = "WidgetAddUnitCommand"
    self.springID = springID
    self.modelID = modelID
end

function WidgetAddUnitCommand:execute()
    SB.model.unitManager:addUnit(self.springID, self.modelID)
end
----------------------------------------------------------
----------------------------------------------------------
WidgetRemoveUnitCommand = Command:extends{}

function WidgetRemoveUnitCommand:init(modelID)
    self.className = "WidgetRemoveUnitCommand"
    self.modelID = modelID
end

function WidgetRemoveUnitCommand:execute()
    SB.model.unitManager:removeUnitByModelID(self.modelID)
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

function UnitManagerListenerGadget:onUnitAdded(unitID, modelID)
    local cmd = WidgetAddUnitCommand(unitID, modelID)
    SB.commandManager:execute(cmd, true)
end

function UnitManagerListenerGadget:onUnitRemoved(unitID, modelID)
    local cmd = WidgetRemoveUnitCommand(modelID)
    SB.commandManager:execute(cmd, true)
end

end
----------------------------------------------------------
-- END Widget callback listener
----------------------------------------------------------
