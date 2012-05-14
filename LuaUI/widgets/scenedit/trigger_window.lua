local Chili = WG.Chili
local C_HEIGHT = 16
local B_HEIGHT = 26
local SCENEDIT_IMG_DIR = LUAUI_DIRNAME .. "images/scenedit/"
local model = SCEN_EDIT.model

TriggerWindow = Chili.Window:Inherit {
    classname = "window",
    clientWidth = 600,
    clientHeight = 250,
    minimumSize = {300,200},
    x = 500,
    y = 300,
    trigger = nil, --required
    _triggerPanel = nil,
}

local this = TriggerWindow 
local inherited = this.inherited

function TriggerWindow:New(obj)
    obj.caption = obj.trigger.name
    obj._triggerPanel = Chili.StackPanel:New {
        itemMargin = {0, 0, 0, 0},
        x = 1,
        y = 1,
        right = 1,
        autosize = true,
        resizeItems = false,
        padding = {0, 0, 0, 0}
    }
    local btnAddEvent = Chili.Button:New {
        caption='Add event',
        width='20%',
        x = 1,
        bottom = 1,
        height = B_HEIGHT,
    }
    local btnAddCondition = Chili.Button:New {
        caption='Add condition',
        width='20%',
        x = '25%',
        bottom = 1,
        height = B_HEIGHT,
    }
    local btnAddAction = Chili.Button:New {
        caption='Add action',
        width='20%',
        x = '50%',
        bottom = 1,
        height = B_HEIGHT,
    }
    local btnClose = Chili.Button:New {
        caption='Close',
        width='20%',
        x = '80%',
        bottom = 1,
        height = B_HEIGHT,
    }
    obj.children = {
        Chili.ScrollPanel:New {
            x = 1,
            y = 15,
            right = 5,
            bottom = B_HEIGHT * 2,
            children = {
                obj._triggerPanel,
            },
        },
        btnAddEvent,
        btnAddCondition,
        btnAddAction,
        btnClose,
    }

    obj = inherited.New(self, obj)
    obj:Populate()
    btnClose.OnClick = {
        function() 
            obj:Dispose() 
        end
    }

    btnAddEvent.OnClick={function() MakeAddEventWindow(obj.trigger, obj) end}
    btnAddCondition.OnClick={function() MakeAddConditionWindow(obj.trigger, obj) end}
    btnAddAction.OnClick={function() MakeAddActionWindow(obj.trigger, obj) end}
    return obj
end

function TriggerWindow:Populate()
    self._triggerPanel:ClearChildren()
    local eventLabel = Chili.Label:New {
        caption = "- Events -",
        height = C_HEIGHT,
        align = 'center',
        parent = self._triggerPanel,
    }
    for i = 1, #self.trigger.events do
        local event = self.trigger.events[i]
        local stackEventPanel = Chili.StackPanel:New {
            parent = self._triggerPanel,
            width = "100%",
            height = B_HEIGHT + 8,
            orientation = "horizontal",
            padding = {0, 0, 0, 0},
            margin = {0, 0, 0, 0},
            itemMarging = {0, 0, 0, 0},
            resizeItems = false,
        }
        local btnEditEvent = Chili.Button:New {
            caption = model.eventTypes[event.eventTypeName].humanName,
            right = B_HEIGHT + 10,
            x = 1,
            height = B_HEIGHT,
            parent = stackEventPanel,
            OnClick = {function() MakeEditEventWindow(self.trigger, self, event) end}
        }
        local btnRemoveEvent = Chili.Button:New {
            caption = "",
            right = 1,
            width = B_HEIGHT,
            height = B_HEIGHT,
            parent = stackEventPanel,
            padding = {0, 0, 0, 0},
            children = {
                Chili.Image:New { 
                    tooltip = "Remove event", 
                    file=SCENEDIT_IMG_DIR .. "list-remove.png", 
                    height = B_HEIGHT, 
                    width = B_HEIGHT, 
                    margin = {0, 0, 0, 0},
                },
            },
            OnClick = {function() MakeRemoveEventWindow(self.trigger, self, event, i) end}
        }
    end
    local conditionLabel = Chili.Label:New {
        caption = "- Conditions -",
        height = C_HEIGHT,
        align = 'center',
        vlign = 'center',
        parent = self._triggerPanel,
    }
    for i = 1, #self.trigger.conditions do
        local condition = self.trigger.conditions[i]
        local stackEventPanel = Chili.StackPanel:New {
            parent = self._triggerPanel,
            width = "100%",
            height = B_HEIGHT + 8,
            orientation = "horizontal",
            padding = {0, 0, 0, 0},
            itemMarging = {0, 0, 0, 0},
            resizeItems = false,
        }
        local btnEditCondition = Chili.Button:New {
            caption = model.conditionTypes[condition.conditionTypeName].humanName,
            right = B_HEIGHT + 10,
            x = 1,
            height = B_HEIGHT,
            parent = stackEventPanel,
            OnClick = {function() MakeEditConditionWindow(self.trigger, self, condition) end}
        }
        local btnRemoveCondition = Chili.Button:New {
            caption = "",
            right = 1,
            width = B_HEIGHT,
            height = B_HEIGHT,
            parent = stackEventPanel,
            padding = {0, 0, 0, 0},
            children = {
                Chili.Image:New { 
                    tooltip = "Remove condition", 
                    file=SCENEDIT_IMG_DIR .. "list-remove.png", 
                    height = B_HEIGHT, 
                    width = B_HEIGHT, 
                    margin = {0, 0, 0, 0},
                },
            },
            OnClick = {function() MakeRemoveConditionWindow(self.trigger, self, condition, i) end}
        }
    end
    local actionLabel = Chili.Label:New {
        caption = "- Actions -",
        height = C_HEIGHT,
        align = 'center',
        parent = self._triggerPanel,
    }
    for i = 1, #self.trigger.actions do
        local action = self.trigger.actions[i]
        local stackActionPanel = Chili.StackPanel:New {
            parent = self._triggerPanel,
            width = "100%",
            height = B_HEIGHT + 8,
            orientation = "horizontal",
            padding = {0, 0, 0, 0},
            itemMarging = {0, 0, 0, 0},
            resizeItems = false,
        }
        local btnEditAction = Chili.Button:New {
            caption = model.actionTypes[action.actionTypeName].humanName,
            right = B_HEIGHT + 10,
            x = 1,
            height = B_HEIGHT,
            parent = stackActionPanel,
            OnClick = {function() MakeEditActionWindow(self.trigger, self, action) end}
        }
        local btnRemoveAction = Chili.Button:New {
            caption = "",
            right = 1,
            width = B_HEIGHT,
            height = B_HEIGHT,
            parent = stackActionPanel,
            padding = {0, 0, 0, 0},
            children = {
                Chili.Image:New { 
                    tooltip = "Remove action", 
                    file= SCENEDIT_IMG_DIR .. "list-remove.png", 
                    height = B_HEIGHT, 
                    width = B_HEIGHT, 
                    margin = {0, 0, 0, 0},
                },
            },
            OnClick = {function() MakeRemoveActionWindow(self.trigger, self, action, i) end},
        }
    end
end

