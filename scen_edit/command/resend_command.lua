ResendCommand = Command:extends{}

-- command sent from widget to gadget to resubmit all data
function ResendCommand:init(metaModelFiles)
    self.className = "ResendCommand"
    self.metaModelFiles = metaModelFiles
end

function ResendCommand:execute()
    Log.Notice("Resend data started...")
    -- TODO: Update to use s11n
    Log.Error("NOT IMPLEMENTED: RESEND")
    -- local cmd = WidgetResendCommand({
    --     s2mUnit = s2mUnit,
    --     s2mFeature = s2mFeature
    -- })
    SB.commandManager:execute(cmd, true)
end

WidgetResendCommand = Command:extends{}

function WidgetResendCommand:init(model)
    self.className = "WidgetResendCommand"
    self.model = model
end

function WidgetResendCommand:execute()
    for name, objectS11N in pairs(s11n.s11nByName) do
        -- do stuff
    end
    Log.Notice("Resend completed successfully.")
end
