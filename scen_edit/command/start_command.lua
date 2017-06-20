StartCommand = Command:extends{}

function StartCommand:init()
    self.className = "StartCommand"
end

function StartCommand:execute()
    if SB.rtModel.hasStarted then
        return
    end

    Log.Notice("Starting game...")

    local oldModel = SB.model:Serialize()
    SB.model.oldModel = oldModel

    local heightMap = HeightMap()
    heightMap:Serialize()
    SB.model.oldHeightMap = heightMap

    SB.rtModel:LoadMission(SB.model:GetMetaData())

    if SB_USE_PLAY_PAUSE then
        Spring.SendCommands("pause 0")
    else
        local allUnits = Spring.GetAllUnits()
        for i = 1, #allUnits do
            local unitId = allUnits[i]
            --[[Spring.GiveOrderToUnit(unitId, CMD.FIRE_STATE, { 2 }, {})
            Spring.MoveCtrl.Disable(unitId)
            SB.delay(function()
                Spring.GiveOrderToUnit(unitId, CMD.WAIT, {}, {})
                Spring.GiveOrderToUnit(unitId, CMD.WAIT, {}, {})
            end)]]--
            Spring.SetUnitHealth(unitId, { paralyze = 0 })
        end
    end

    Spring.SetGameRulesParam("sb_gameMode", "test")
    SB.rtModel:GameStart()
end
