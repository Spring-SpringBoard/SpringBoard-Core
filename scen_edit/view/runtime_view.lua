local C_HEIGHT = 16
local B_HEIGHT = 24
local SCEN_EDIT_IMG_DIR = LUAUI_DIRNAME .. "images/scenedit/"

RuntimeView = LCS.class{}

function RuntimeView:init()
    self.mode = "trigger"
    self.started = false --check instead of assuming
    self.btnStartStop = Button:New {
        caption='',
        height = B_HEIGHT + 20,
        width = B_HEIGHT + 20,
        OnClick = {
            function() 
                if not self.started then
                    local cmd = StartCommand()
                    SCEN_EDIT.commandManager:execute(cmd)
                    self:GameStarted()
                else
                    local cmd = StopCommand()
                    SCEN_EDIT.commandManager:execute(cmd)
                    self:GameStopped()
                end
            end
        }
    }
    self:UpdateStartStopButton()
    self.dvv = StackPanel:New {
        itemMargin = {0, 0, 0, 0},
        x = 1,
        y = 1,
        right = 1,
        autosize = true,
        resizeItems = false,
    }
    self.dtv = StackPanel:New {
        itemMargin = {0, 0, 0, 0},
        x = 1,
        y = 1,
        right = 1,
        autosize = true,
        resizeItems = false,
    }
    local btnToggleShowDevelop = Button:New {
        caption='Toggle Display',
        width= 80,
        height = B_HEIGHT + 20,
        OnClick = {
            function() 
                SCEN_EDIT.view.displayDevelop = not SCEN_EDIT.view.displayDevelop
            end
        }
    }
    self.runtimeViewWindow = Window:New {
        parent = screen0,
        caption = "Runtime Window",
        x = 1300,
        y = 300,
        minimumSize = {450, 400},
        width = 500,
        height = 600,
        children = {
            StackPanel:New {
                y = 15,
                x = 1,
                right = 1,
                bottom = B_HEIGHT * 2 + 10,
                itemMargin = {0, 0, 0, 0},
                children = {
                    ScrollPanel:New {
		    	width = "100%",
                        height = "100%",
                        children = { 
                            self.dvv,
                        },
                    },
                    ScrollPanel:New {
		    	width = "100%",
			height = "100%",
                        children = { 
                            self.dtv,
                        },
                    },
                },
            },
            StackPanel:New {
                orientation = 'horizontal',
                width = '100%',
                bottom = 1,
                height = B_HEIGHT * 3,
                padding = {0,0,0,0},
                itemPadding = {0,10,10,10},
                itemMargin = {0,0,0,0},
                resizeItems = false,
                children = {
                    self.btnStartStop,
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

function RuntimeView:UpdateStartStopButton()
    self.btnStartStop:ClearChildren()
    if not self.started then
        self.btnStartStop:AddChild(
            Image:New {
                tooltip = "Start mission",
                file = SCEN_EDIT_IMG_DIR .. "media-playback-start.png",
                height = B_HEIGHT - 2,
                width = B_HEIGHT - 2,
                margin = {0, 0, 0, 0},
            }
        )
    else
        self.btnStartStop:AddChild(
            Image:New {
                tooltip = "Stop mission",
                file = SCEN_EDIT_IMG_DIR .. "media-playback-stop.png",
                height = B_HEIGHT - 2,
                width = B_HEIGHT - 2,
                margin = {0, 0, 0, 0},
            }
        )
    end
end

function RuntimeView:GameStarted()
    self.started = true
    self:UpdateStartStopButton()
end

function RuntimeView:GameStopped()
    self.started = false
    self:UpdateStartStopButton()
end
