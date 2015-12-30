ResendCommand = AbstractCommand:extends{}

-- command sent from widget to gadget to resubmit all data
function ResendCommand:init(metaModelFiles)
    self.className = "ResendCommand"
    self.metaModelFiles = metaModelFiles
end

function ResendCommand:execute()
	Spring.Log("scened", LOG.NOTICE, "Resend data started...")
    local s2mUnit =     SCEN_EDIT.model.unitManager.s2mUnitIdMapping
    local s2mFeature =  SCEN_EDIT.model.featureManager.s2mFeatureIdMapping
    local cmd = WidgetResendCommand({
        s2mUnit = s2mUnit,
        s2mFeature = s2mFeature
    })
    SCEN_EDIT.commandManager:execute(cmd, true)
end

WidgetResendCommand = AbstractCommand:extends{}

function WidgetResendCommand:init(model)
    self.className = "WidgetResendCommand"
    self.model = model
end

function WidgetResendCommand:execute()
    for objectID, modelID in pairs(self.model.s2mUnit) do
        SCEN_EDIT.model.unitManager:setUnitModelId(objectID, modelID)
    end
    for objectID, modelID in pairs(self.model.s2mFeature) do
        SCEN_EDIT.model.featureManager:setFeatureModelId(objectID, modelID)
    end
    Spring.Log("scened", LOG.NOTICE, "Resend completed successfully.")
end
