MainWindow = LCS.class{}

function MainWindow:init()
    self.toolboxWindow = Window:New {
        x = 1000,
        y = 100,
        width = 800,
        height = 80,
        parent = screen0,
        caption = "Scenario Toolbox",
        resizable = false,
        children = {
            StackPanel:New {
                name='stack_main',
                orientation = 'horizontal',
                width = '100%',
                height = '100%',
                padding = {0,0,0,0},
                itemPadding = {0,10,10,10},
                itemMargin = {0,0,0,0},
                resizeItems = false,
				centerItems = false,

                children = {
                    Button:New {
                        height = SCEN_EDIT.conf.B_HEIGHT + 20,
                        width = SCEN_EDIT.conf.B_HEIGHT + 220,
                        caption = 'EXPORT-IMG(hello carp)',
                        OnClick = {
                            function()
                                SCEN_EDIT.delayGL(function()
                                    local command = SaveImagesCommand("./")
                                    SCEN_EDIT.commandManager:execute(command, true)
                                end
                                )
                            end
                        },
                    },--[[
                    Button:New {
                        height = SCEN_EDIT.conf.B_HEIGHT + 20,
                        width = SCEN_EDIT.conf.B_HEIGHT + 20,
                        caption = '',
                        OnClick = {
                            function()
                                Spring.StopSoundStream()
--                                Spring.PlaySoundStream("sounds/environment.ogg")
--                                Spring.PlaySoundFile("sounds/environment.ogg")
--                                Spring.Restart("tb.txt2", "")
--                                local cmd = StartCommand()
--                                SCEN_EDIT.commandManager:execute(cmd)
                            end
                        },
                        children = {
                            Image:New {
                                tooltip = "Start mission",
                                file = SCEN_EDIT_IMG_DIR .. "media-playback-start.png",
                                height = SCEN_EDIT.conf.B_HEIGHT - 2,
                                width = SCEN_EDIT.conf.B_HEIGHT - 2,
                                margin = {0, 0, 0, 0},
                            },
                        },
                    },--]]
                 }
            }
        }
    }
end
