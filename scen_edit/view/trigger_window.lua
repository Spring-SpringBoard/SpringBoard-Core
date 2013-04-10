TriggerWindow = Window:Inherit {
    classname = "window",
    clientWidth = 600,
    clientHeight = 250,
    minimumSize = {500,200},
    x = 500,
    y = 300,
    trigger = nil, --required
    _triggerPanel = nil,
}

local this = TriggerWindow 
local inherited = this.inherited

function TriggerWindow:New(obj)
    obj.caption = obj.trigger.name
    local stackTriggerPanel = MakeComponentPanel(nil)
    stackTriggerPanel.y = 10
    local lblTriggerName = Label:New {
        caption = "Trigger name: ",
        right = 100 + 10,
        x = 1,
        parent = stackTriggerPanel,
    }
    local edTriggerName = EditBox:New {
        text = obj.trigger.name,
        right = 1,
        width = 100,
        parent = stackTriggerPanel,
    }
    obj._triggerPanel = StackPanel:New {
        itemMargin = {0, 0, 0, 0},
        x = 1,
        y = 1,
        right = 1,
        autosize = true,
        resizeItems = false,
        padding = {0, 0, 0, 0}
    }
    local btnAddEvent = Button:New {
        caption='Add event',
        width=110,
        x = 1,
        bottom = 1,
        height = SCEN_EDIT.conf.B_HEIGHT,
    }
    local btnAddCondition = Button:New {
        caption='Add condition',
        width=120,
        x = 120,
        bottom = 1,
        height = SCEN_EDIT.conf.B_HEIGHT,
    }
    local btnAddAction = Button:New {
        caption='Add action',
        width=110,
        x = 250,
        bottom = 1,
        height = SCEN_EDIT.conf.B_HEIGHT,
    }
    local btnClose = Button:New {
        caption='Close',
        width=100,
        x = 370,
        bottom = 1,
        height = SCEN_EDIT.conf.B_HEIGHT,
    }
    obj.children = {
        stackTriggerPanel,
        ScrollPanel:New {
            x = 1,
            y = 15 + SCEN_EDIT.conf.B_HEIGHT,
            right = 5,
            bottom = SCEN_EDIT.conf.B_HEIGHT * 2,
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
            obj.trigger.name = edTriggerName.text
            obj:Dispose()             
        end
    }

    btnAddEvent.OnClick={function() obj:MakeAddEventWindow() end}
    btnAddCondition.OnClick={function() obj:MakeAddConditionWindow() end}
    btnAddAction.OnClick={function() obj:MakeAddActionWindow() end}
    return obj
end

function TriggerWindow:Populate()
    self._triggerPanel:ClearChildren()
    local eventLabel = Label:New {
        caption = "- Events -",
        height = SCEN_EDIT.conf.C_HEIGHT,
        align = 'center',
        parent = self._triggerPanel,
    }
    for i = 1, #self.trigger.events do
        local event = self.trigger.events[i]
        local stackEventPanel = MakeComponentPanel(self._triggerPanel)
        local btnEditEvent = Button:New {
            caption = SCEN_EDIT.metaModel.eventTypes[event.eventTypeName].humanName,
            right = SCEN_EDIT.conf.B_HEIGHT + 10,
            x = 1,
            height = SCEN_EDIT.conf.B_HEIGHT,
            parent = stackEventPanel,
            OnClick = {function() self:MakeEditEventWindow(event) end}
        }
        local btnRemoveEvent = Button:New {
            caption = "",
            right = 1,
            width = SCEN_EDIT.conf.B_HEIGHT,
            height = SCEN_EDIT.conf.B_HEIGHT,
            parent = stackEventPanel,
            padding = {0, 0, 0, 0},
            children = {
                Image:New { 
                    tooltip = "Remove event", 
                    file=SCEN_EDIT_IMG_DIR .. "list-remove.png", 
                    height = SCEN_EDIT.conf.B_HEIGHT, 
                    width = SCEN_EDIT.conf.B_HEIGHT, 
                    margin = {0, 0, 0, 0},
                },
            },
            OnClick = {function() self:MakeRemoveEventWindow(event, i) end}
        }
    end
    local conditionLabel = Label:New {
        caption = "- Conditions -",
        height = SCEN_EDIT.conf.C_HEIGHT,
        align = 'center',
        vlign = 'center',
        parent = self._triggerPanel,
    }
    for i = 1, #self.trigger.conditions do
        local condition = self.trigger.conditions[i]
        local stackEventPanel = MakeComponentPanel(self._triggerPanel)
        local conditionHumanName = SCEN_EDIT.humanExpression(condition, "condition")
        local btnEditCondition = Button:New {
            caption = conditionHumanName,
            right = SCEN_EDIT.conf.B_HEIGHT + 10,
            x = 1,
            height = SCEN_EDIT.conf.B_HEIGHT,
            parent = stackEventPanel,
            OnClick = {function() self:MakeEditConditionWindow(condition) end}
        }
        local btnRemoveCondition = Button:New {
            caption = "",
            right = 1,
            width = SCEN_EDIT.conf.B_HEIGHT,
            height = SCEN_EDIT.conf.B_HEIGHT,
            parent = stackEventPanel,
            padding = {0, 0, 0, 0},
            children = {
                Image:New { 
                    tooltip = "Remove condition", 
                    file=SCEN_EDIT_IMG_DIR .. "list-remove.png", 
                    height = SCEN_EDIT.conf.B_HEIGHT, 
                    width = SCEN_EDIT.conf.B_HEIGHT, 
                    margin = {0, 0, 0, 0},
                },
            },
            OnClick = {function() self:MakeRemoveConditionWindow(condition, i) end}
        }
    end
    local actionLabel = Label:New {
        caption = "- Actions -",
        height = SCEN_EDIT.conf.C_HEIGHT,
        align = 'center',
        parent = self._triggerPanel,
    }
    for i = 1, #self.trigger.actions do
        local action = self.trigger.actions[i]
        local stackActionPanel = MakeComponentPanel(self._triggerPanel)
        local actionHumanName = SCEN_EDIT.humanExpression(action, "action")
        local btnEditAction = Button:New {
            caption = actionHumanName,
            right = SCEN_EDIT.conf.B_HEIGHT + 10,
            x = 1,
            height = SCEN_EDIT.conf.B_HEIGHT,
            parent = stackActionPanel,
            OnClick = {function() self:MakeEditActionWindow(action) end}
        }
        local btnRemoveAction = Button:New {
            caption = "",
            right = 1,
            width = SCEN_EDIT.conf.B_HEIGHT,
            height = SCEN_EDIT.conf.B_HEIGHT,
            parent = stackActionPanel,
            padding = {0, 0, 0, 0},
            children = {
                Image:New { 
                    tooltip = "Remove action", 
                    file= SCEN_EDIT_IMG_DIR .. "list-remove.png", 
                    height = SCEN_EDIT.conf.B_HEIGHT, 
                    width = SCEN_EDIT.conf.B_HEIGHT, 
                    margin = {0, 0, 0, 0},
                },
            },
            OnClick = {function() self:MakeRemoveActionWindow(action, i) end},
        }
    end
end

function TriggerWindow:MakeAddConditionWindow()
    local newActionWindow = ConditionWindow:New {
         parent = screen0,
        trigger = self.trigger,
        triggerWindow = self,
        mode = 'add',
    }
end

function TriggerWindow:MakeEditConditionWindow(condition)
    local newActionWindow = ConditionWindow:New {
         parent = screen0,    
        trigger = self.trigger,
        triggerWindow = self,
        mode = 'edit',
        condition = condition,
    }
end

function TriggerWindow:MakeRemoveConditionWindow(condition, idx)
    table.remove(self.trigger.conditions, idx)
    self:Populate()
end

function TriggerWindow:MakeAddEventWindow()
    local newEventWindow = EventWindow:New {
         parent = screen0,
        trigger = self.trigger,
        triggerWindow = self,
        mode = 'add',
    }
end

function TriggerWindow:MakeEditEventWindow(event)
    local newEventWindow = EventWindow:New {
         parent = screen0,
        trigger = self.trigger,
        triggerWindow = self,
        mode = 'edit',
        event = event,
    }
end

function TriggerWindow:MakeRemoveEventWindow(event, idx)
    table.remove(self.trigger.events, idx)
    self:Populate()
end

function TriggerWindow:MakeAddActionWindow()
    local newActionWindow = ActionWindow:New {
        parent = screen0,
        trigger = self.trigger,
        triggerWindow = self,
        mode = 'add',
    }
end

function TriggerWindow:MakeEditActionWindow(action)
    local newActionWindow = ActionWindow:New {
        parent = screen0,
        trigger = self.trigger,
        triggerWindow = self,
        mode = 'edit',
        action = action,
    }
end

function TriggerWindow:MakeRemoveActionWindow(action, idx)
    table.remove(self.trigger.actions, idx)
    self:Populate()
end

