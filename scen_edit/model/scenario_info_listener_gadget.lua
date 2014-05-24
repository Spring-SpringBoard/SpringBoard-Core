ScenarioInfoListenerGadget = ScenarioInfoListener:extends{}

function ScenarioInfoListenerGadget:init()
end

function ScenarioInfoListenerGadget:onSet(name, description, version, author)
    local cmd = WidgetSetScenarioInfoCommand(name, description, version, author)
    SCEN_EDIT.commandManager:execute(cmd, true)
end
