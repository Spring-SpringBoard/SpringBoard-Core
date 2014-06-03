return {
    functions = {
    },
    actions = {
        {
            humanName = "Unit say", 
            name = "UNIT_SAY",
            input = { "unit", "string" },
            execute = function (input)
                local unit = input.unit
                local text = input.string

                SCEN_EDIT.displayUtil:unitSay(unit, text)
            end
        },
        {
            humanName = "Move unit", 
            name = "MOVE_UNIT",
            input = { "unit", "area" },
            tags = {"Unit"},
            execute = function (input)
                local unit = input.unit
                local area = input.area
                local x = (area[1] + area[3]) / 2
                local z = (area[2] + area[4]) / 2
                local y = Spring.GetGroundHeight(x, z)
                Spring.SetUnitPosition(unit, x, y, z)
                Spring.GiveOrderToUnit(unit, CMD.STOP, {}, {})
            end
        },
        {
            humanName = "Execute trigger after n seconds",
            name = "EXECUTE_TRIGGER_AFTER_TIME",
            input = { "trigger", "number" },
            doRepeat = true,
            execute = function (input)
                local trigger = input.trigger
                if not input.converted then
                    input.converted = true
                    input.number = input.number * 30
                end
                if input.number > 0 then
                    input.number = input.number - 1
                    return true
                else
                    SCEN_EDIT.rtModel:ExecuteTrigger(trigger.id)
                end
            end
        },
    },
}
