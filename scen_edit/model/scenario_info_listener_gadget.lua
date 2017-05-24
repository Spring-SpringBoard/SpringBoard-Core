ScenarioInfoListenerGadget = ScenarioInfoListener:extends{}

function ScenarioInfoListenerGadget:init()
end

function ScenarioInfoListenerGadget:onSet(name, description, version, author)
    local cmd = WidgetSetScenarioInfoCommand(name, description, version, author)
    SB.commandManager:execute(cmd, true)
end
