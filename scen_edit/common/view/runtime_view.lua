local Chili = WG.Chili
local screen0 = Chili.Screen0
local C_HEIGHT = 16
local B_HEIGHT = 24
local SCEN_EDIT_IMG_DIR = LUAUI_DIRNAME .. "images/scenedit/"

RuntimeView = LCS.class{}

function RuntimeView:init()
    self.mode = "trigger"
    local btnPlay = Chili.Button:New {
        caption='',
        height = B_HEIGHT + 20,
        width = B_HEIGHT + 20,
        children = {
            Chili.Image:New {
                tooltip = "Start mission",
                file = SCEN_EDIT_IMG_DIR .. "media-playback-start.png",
                height = B_HEIGHT - 2,
                width = B_HEIGHT - 2,
                margin = {0, 0, 0, 0},
            },
        },
        OnClick = {
            function() 
                local cmd = StartCommand()
                SCEN_EDIT.commandManager:execute(cmd)
            end
        }
    }
    local btnStop = Chili.Button:New {
        caption='',
        height = B_HEIGHT + 20,
        width = B_HEIGHT + 20,
        children = {
            Chili.Image:New {
                tooltip = "Stop mission",
                file = SCEN_EDIT_IMG_DIR .. "media-playback-stop.png",
                height = B_HEIGHT - 2,
                width = B_HEIGHT - 2,
                margin = {0, 0, 0, 0},
            },
        },
        OnClick = {
            function() 
                local cmd = StopCommand()
                SCEN_EDIT.commandManager:execute(cmd)
            end
        }
    }
    self.dvv = Chili.StackPanel:New {
        itemMargin = {0, 0, 0, 0},
        x = 1,
        y = 1,
        right = 1,
        autosize = true,
        resizeItems = false,
    }
    self.dtv = Chili.StackPanel:New {
        itemMargin = {0, 0, 0, 0},
        x = 1,
        y = 1,
        right = 1,
        autosize = true,
        resizeItems = false,
    }
    self.cbType = ComboBox:New {
        items = { "trigger", "variable" },
        width = 80,
        height = B_HEIGHT + 20,
        OnSelectItem = {
            function(obj, itemIdx, selected)
                if selected and itemIdx > 0 then
                    if itemIdx == 1 then 
                        self.mode = "trigger"
                    else 
                        self.mode = "variable"
                    end
                    self:Populate()
                end
            end
        },
    }
    local btnToggleShowDevelop = Chili.Button:New {
        caption='Toggle Display',
        width= 80,
        height = B_HEIGHT + 20,
        OnClick = {
            function() 
                SCEN_EDIT.view.displayDevelop = not SCEN_EDIT.view.displayDevelop
            end
        }
    }
    self.runtimeViewWindow = Chili.Window:New {
        parent = screen0,
        caption = "Runtime Window",
        x = 1300,
        y = 300,
        minimumSize = {450, 400},
        width = 500,
        height = 600,
        children = {
            Chili.StackPanel:New {
                y = 15,
                x = 1,
                right = 1,
                bottom = B_HEIGHT * 2 + 10,
                itemMargin = {0, 0, 0, 0},
                children = {
                    Chili.ScrollPanel:New {
                        x = 1,
                        y = 1,
                        height = "50%",
                        right = 1,
                        children = { 
                            self.dvv,
                        },
                    },
                    Chili.ScrollPanel:New {
                        x = 1,
                        y = "50%",
                        right = 1,
                        bottom = 1,
                        children = { 
                            self.dtv,
                        },
                    },
                },
            },
            Chili.StackPanel:New {
                orientation = 'horizontal',
                width = '100%',
                bottom = 1,
                height = B_HEIGHT * 3,
                padding = {0,0,0,0},
                itemPadding = {0,10,10,10},
                itemMargin = {0,0,0,0},
                resizeItems = false,
                children = {
                    btnPlay,
                    btnStop,
                    self.cbType,
                    btnToggleShowDevelop,
                },
            },
        }
    }
    self:Populate()
end

function RuntimeView:Populate()
    DebugTriggerView(self.dtv)
    DebugVariableView(self.dvv)
end
