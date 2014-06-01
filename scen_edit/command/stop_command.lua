StopCommand = AbstractCommand:extends{}

function StopCommand:init()
    self.className = "StopCommand"
end

function StopCommand:execute()
    if SCEN_EDIT.rtModel.hasStarted then
        SCEN_EDIT.rtModel:GameStop()
        -- use meta data (except variables) from the new (runtime) model
        -- enable all triggers
        local meta = SCEN_EDIT.model:GetMetaData()
        for _, trigger in pairs(meta.triggers) do
            trigger.enabled = true
        end
        meta.variables = SCEN_EDIT.model.oldModel.meta.variables

        SCEN_EDIT.model.oldModel.meta = meta

        SCEN_EDIT.model:Load(SCEN_EDIT.model.oldModel)
    end
end
