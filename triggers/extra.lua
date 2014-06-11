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
