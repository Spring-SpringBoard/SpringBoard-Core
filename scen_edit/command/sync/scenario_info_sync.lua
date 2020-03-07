SB.Include(Path.Join(SB.DIRS.SRC, 'model/scenario_info.lua'))

----------------------------------------------------------
-- Widget callback commands
----------------------------------------------------------
WidgetSetScenarioInfoCommand = Command:extends{}
WidgetSetScenarioInfoCommand.className = "WidgetSetScenarioInfoCommand"

function WidgetSetScenarioInfoCommand:init(data)
    self.data = data
end

function WidgetSetScenarioInfoCommand:execute()
    SB.model.scenarioInfo:Set(self.data)
end
----------------------------------------------------------
-- END Widget callback commands
----------------------------------------------------------

----------------------------------------------------------
-- Widget callback listener
----------------------------------------------------------
if SB.SyncModel then

ScenarioInfoListenerGadget = ScenarioInfoListener:extends{}
SB.OnInitialize(function()
    SB.model.scenarioInfo:addListener(ScenarioInfoListenerGadget())
end)

function ScenarioInfoListenerGadget:onSet(data)
    local cmd = WidgetSetScenarioInfoCommand(data)
    SB.commandManager:execute(cmd, true)
end

end
----------------------------------------------------------
-- END Widget callback listener
----------------------------------------------------------
