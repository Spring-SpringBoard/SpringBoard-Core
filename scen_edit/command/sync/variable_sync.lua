SB.Include(Path.Join(SB_MODEL_DIR, "variable_manager.lua"))

----------------------------------------------------------
-- Widget callback commands
----------------------------------------------------------
WidgetAddVariableCommand = Command:extends{}

function WidgetAddVariableCommand:init(id, value)
    self.className = "WidgetAddVariableCommand"
    self.id = id
    self.value = value
end

function WidgetAddVariableCommand:execute()
    self.newVar = self.value
    self.newVar.id = self.id
    SB.model.variableManager:addVariable(self.newVar)
end
----------------------------------------------------------
----------------------------------------------------------
WidgetRemoveVariableCommand = Command:extends{}

function WidgetRemoveVariableCommand:init(id)
    self.className = "WidgetRemoveVariableCommand"
    self.id = id
end

function WidgetRemoveVariableCommand:execute()
    SB.model.variableManager:removeVariable(self.id)
end
----------------------------------------------------------
----------------------------------------------------------
WidgetUpdateVariableCommand = Command:extends{}

function WidgetUpdateVariableCommand:init(variable)
    self.className = "WidgetUpdateVariableCommand"
    self.variable = variable
end

function WidgetUpdateVariableCommand:execute()
    SB.model.variableManager:setVariable(self.variable.id, self.variable)
end
----------------------------------------------------------
-- END Widget callback commands
----------------------------------------------------------

----------------------------------------------------------
-- Widget callback listener
----------------------------------------------------------
if SB.SyncModel then

VariableManagerListenerGadget = VariableManagerListener:extends{}
SB.OnInitialize(function()
    SB.model.variableManager:addListener(VariableManagerListenerGadget())
end)

function VariableManagerListenerGadget:onVariableAdded(variableId)
    local variable = SB.model.variableManager:getVariable(variableId)
    local cmd = WidgetAddVariableCommand(variableId, variable)
    SB.commandManager:execute(cmd, true)
end

function VariableManagerListenerGadget:onVariableRemoved(variableId)
    local cmd = WidgetRemoveVariableCommand(variableId)
    SB.commandManager:execute(cmd, true)
end

function VariableManagerListenerGadget:onVariableUpdated(variableId)
    local variable = SB.model.variableManager:getVariable(variableId)
    local cmd = WidgetUpdateVariableCommand(variable)
    SB.commandManager:execute(cmd, true)
end

end
----------------------------------------------------------
-- END Widget callback listener
----------------------------------------------------------
