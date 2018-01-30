ReloadMetaModelCommand = Command:extends{}

-- sends meta model files from widget to gadget
function ReloadMetaModelCommand:init(metaModelFiles)
    self.className = "ReloadMetaModelCommand"
    self.metaModelFiles = metaModelFiles
end

function ReloadMetaModelCommand:execute()
    Log.Notice("Reloading meta model...")
    SB.conf:SetMetaModelFiles(self.metaModelFiles)
    local metaModelLoader = MetaModelLoader()
    metaModelLoader:Load()
    Log.Notice("Reload completed successfully")
    Log.Notice("Validating trggers...")
    for _, trigger in pairs(SB.model.triggerManager:getAllTriggers()) do
        local success, msg = SB.model.triggerManager:ValidateTrigger(trigger)
        if not success then
            Log.Warning("Trigger error: " .. tostring(trigger.id) .. ". " .. tostring(msg))
            return
        end
    end
    Log.Notice("Trigger validation complete.")
end
