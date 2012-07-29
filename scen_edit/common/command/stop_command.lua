StopCommand = AbstractCommand:extends{}

function StopCommand:init()
    self.className = "StopCommand"
end

function StopCommand:execute()
    if SCEN_EDIT.rtModel.hasStarted then
        SCEN_EDIT.rtModel:GameStop()
        SCEN_EDIT.model:Load(SCEN_EDIT.model.oldModel)
    end
end
