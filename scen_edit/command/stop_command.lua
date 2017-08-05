StopCommand = Command:extends{}

function StopCommand:init()
    self.className = "StopCommand"
end

function StopCommand:execute()
    if not SB.rtModel.hasStarted then
        return
    end

    Log.Notice("Stopping game...")

    for _, allyTeamID in ipairs(Spring.GetAllyTeamList()) do
        Spring.SetGlobalLos(allyTeamID, true)
    end

    Spring.StopSoundStream()
    Spring.SetGameRulesParam("sb_gameMode", "dev")
    SB.rtModel:GameStop()
    -- use meta data (except variables) from the new (runtime) model
    -- enable all triggers
    local meta = SB.model:GetMetaData()
    for _, trigger in pairs(meta.triggers) do
        trigger.enabled = true
    end
    meta.variables = SB.model.oldModel.meta.variables

    SB.model.oldModel.meta = meta

    --SB.delay(function()
        SB.model:Load(SB.model.oldModel)
        SB.model.oldHeightMap:Load()
    --end)
    if SB_USE_PLAY_PAUSE then
        Spring.SendCommands("pause 1")
    end
end
