VariableManagerListenerWidget = VariableManagerListener:extends{}

function VariableManagerListenerWidget:init(variableWindow)
    self.variableWindow = variableWindow
end

function VariableManagerListenerWidget:onVariableAdded(variableId)
    self.variableWindow:Populate()
end

function VariableManagerListenerWidget:onVariableRemoved(variableId)
    self.variableWindow:Populate()
end

function VariableManagerListenerWidget:onVariableUpdated(variableId)
    self.variableWindow:Populate()
end
