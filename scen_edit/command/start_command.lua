StartCommand = AbstractCommand:extends{}

function StartCommand:init()
    self.className = "StartCommand"
end

function StartCommand:execute()
    Spring.Log("Scened", LOG.NOTICE, "Start command")
        Spring.Echo("STARTCOMMAND", SCEN_EDIT.rtModel.hasStarted)

    if not SCEN_EDIT.rtModel.hasStarted then
        local oldModel = SCEN_EDIT.model:Serialize()
        SCEN_EDIT.model.oldModel = oldModel

        local heightMap = HeightMap()
        heightMap:Serialize()
        SCEN_EDIT.model.oldHeightMap = heightMap

        SCEN_EDIT.rtModel:LoadMission(SCEN_EDIT.model:GetMetaData())
        local allUnits = Spring.GetAllUnits()
        for i = 1, #allUnits do
            local unitId = allUnits[i]
            --[[Spring.GiveOrderToUnit(unitId, CMD.FIRE_STATE, { 2 }, {})
            Spring.MoveCtrl.Disable(unitId)
            SCEN_EDIT.delay(function()
                Spring.GiveOrderToUnit(unitId, CMD.WAIT, {}, {})
                Spring.GiveOrderToUnit(unitId, CMD.WAIT, {}, {})
            end)]]--
            Spring.SetUnitHealth(unitId, { paralyze = 0 })
        end
        SCEN_EDIT.rtModel:GameStart()
    end
    Spring.Echo("STARTCOMMAND", SCEN_EDIT.rtModel.hasStarted)
end
