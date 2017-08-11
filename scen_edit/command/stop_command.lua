StopCommand = Command:extends{}

function StopCommand:init()
    self.className = "StopCommand"
end

function StopCommand:execute()
    if not SB.rtModel.hasStarted then
        return
    end

    pcall(function()
        local OnStartEditingSynced = SB.model.game.OnStartEditingSynced
        if OnStartEditingSynced then
            OnStartEditingSynced()
        end
    end)

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

    local teamData = SB.model.oldModel.meta.teams
    SB.model.oldModel.meta = meta

    --SB.delay(function()
        SB.model:Load(SB.model.oldModel)
        SB.model.oldHeightMap:Load()
    --end)

    SB.model.teamManager:load(teamData)
    if SB_USE_PLAY_PAUSE then
        Spring.SendCommands("pause 1")
    end
end
