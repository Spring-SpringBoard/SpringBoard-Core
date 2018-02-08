return {
    dataTypes = {
        {
            humanName = "Person",
            name = "person",
            input = {
                {
                    name = "first_name",
                    humanName = "First name",
                    type = "string",
                },
                {
                    name = "last_name",
                    humanName = "Last name",
                    type = "string",
                }
            }
        },
    },
    events = {
        {
            humanName = "Closed Dialog",
            name = "UI_DIALOG_CLOSE",
        },
    },
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

                SB.displayUtil:unitSay(unit, text)
            end
        },
        {
            humanName = "Print person",
            name = "PRINT_PERSON",
            input = "person",
            tags = {"Person"},
            execute = function (input)
                local person = input.person
                Spring.Echo("Hello! I am " .. person.first_name .. " " ..
                    person.last_name)
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
                    SB.rtModel:ExecuteTrigger(trigger.id)
                end
            end
        },
        {
            humanName = "Dialog",
            name = "UI_DIALOG",
            input = { "string" },
            tags = {"Dialog"},
            executeUnsynced = function (input)
                local text = input.string

                local Chili = WG.Chili

                local window = nil
                window = Chili.Window:New {
                    caption = "",
                    x = "30%",
                    y = "30%",
                    width = "20%",
                    height = "20%",
                    resizable = false,
                    draggable = false,
                    parent = screen0,
                    name = tostring(os.clock()),
                    children = {
                        Chili.TextBox:New {
                            x = 40,
                            right = 0,
                    		y = 15,
                    		bottom = 50,
                            text = text,
                        },
                        Chili.Button:New {
                            caption = "OK",
                            x = 76,
                            width = 135,
                            bottom = 1,
                            height = 40,
                            OnClick = {
                                function()
                                    Spring.SendCommands("pause 0")
                                    SB.commandManager:execute(OnEventCommand("UI_DIALOG_CLOSE"))
                                    window:Dispose()
                                end
                            },
                        },
                    },
                }
                Spring.SendCommands("pause 1")
            end
        },
    },
}
