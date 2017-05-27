ResendCommand = Command:extends{}

-- command sent from widget to gadget to resubmit all data
function ResendCommand:init(metaModelFiles)
    self.className = "ResendCommand"
    self.metaModelFiles = metaModelFiles
end

function ResendCommand:execute()
	Log.Notice("Resend data started...")
    local s2mUnit =     SB.model.unitManager.s2mUnitIdMapping
    local s2mFeature =  SB.model.featureManager.s2mFeatureIdMapping
    local cmd = WidgetResendCommand({
        s2mUnit = s2mUnit,
        s2mFeature = s2mFeature
    })
    SB.commandManager:execute(cmd, true)
end

WidgetResendCommand = Command:extends{}

function WidgetResendCommand:init(model)
    self.className = "WidgetResendCommand"
    self.model = model
end

function WidgetResendCommand:execute()
    for objectID, modelID in pairs(self.model.s2mUnit) do
        SB.model.unitManager:setUnitModelId(objectID, modelID)
    end
    for objectID, modelID in pairs(self.model.s2mFeature) do
        SB.model.featureManager:setFeatureModelId(objectID, modelID)
    end
    Log.Notice("Resend completed successfully.")
end
