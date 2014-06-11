TriggerWindow = LCS.class{}

function TriggerWindow:init(trigger)
    self.trigger = trigger
    self._triggerPanel = nil
    self.openedConditionNodes = {}
    self.openedActionNodes = {}

    local stackTriggerPanel = MakeComponentPanel(nil)
    stackTriggerPanel.y = 10
    local lblTriggerName = Label:New {
        caption = "Name: ",
        x = 1,
        parent = stackTriggerPanel,
    }
    local edTriggerName = EditBox:New {
        text = self.trigger.name,
        x = 100,
        width = 100,
        parent = stackTriggerPanel,
    }
    self._triggerPanel = StackPanel:New {
        itemMargin = {0, 0, 0, 0},
        x = 1,
        y = 1,
        right = 1,
        autosize = true,
        resizeItems = false,
        padding = {0, 0, 0, 0}
    }
    local btnAddEvent = Button:New {
        caption='+ Event',
        width=110,
        x = 1,
        bottom = 1,
        height = SCEN_EDIT.conf.B_HEIGHT,
        backgroundColor = SCEN_EDIT.conf.BTN_ADD_COLOR,
    }
    local btnAddCondition = Button:New {
        caption='+ Condition',
        width=120,
        x = 120,
        bottom = 1,
        height = SCEN_EDIT.conf.B_HEIGHT,
        backgroundColor = SCEN_EDIT.conf.BTN_ADD_COLOR,
    }
    local btnAddAction = Button:New {
        caption='+ Action',
        width=110,
        x = 250,
        bottom = 1,
        height = SCEN_EDIT.conf.B_HEIGHT,
        backgroundColor = SCEN_EDIT.conf.BTN_ADD_COLOR,
    }
	local btnOk = Button:New {
        caption='OK',
        width=100,
        x = 370,
        bottom = 1,
        height = SCEN_EDIT.conf.B_HEIGHT,
        backgroundColor = SCEN_EDIT.conf.BTN_OK_COLOR,
		OnClick = {
			function() 
				self.trigger.name = edTriggerName.text
				self.save = true
				self.window:Dispose()
			end
		}
    }
    local btnCancel = Button:New {
        caption='Cancel',
        width=100,
        x = 480,
        bottom = 1,
        height = SCEN_EDIT.conf.B_HEIGHT,
        backgroundColor = SCEN_EDIT.conf.BTN_CANCEL_COLOR,
        OnClick={function() self.window:Dispose() end}
    }

    self.window = Window:New {
        width = 610,
        height = 350,
        minimumSize = {500,300},
        x = 500,
        y = 300,
        caption = self.trigger.name,
        parent = screen0,
        children = {
            stackTriggerPanel,
            ScrollPanel:New {
                x = 1,
                y = 15 + SCEN_EDIT.conf.B_HEIGHT,
                right = 5,
                bottom = SCEN_EDIT.conf.B_HEIGHT * 2,
                children = {
                    self._triggerPanel,
                },
            },
            btnAddEvent,
            btnAddCondition,
            btnAddAction,
            btnOk,
            btnCancel,
        }
    }

    self:Populate()

    btnAddEvent.OnClick={function() self:MakeAddEventWindow() end}
    btnAddCondition.OnClick={function() self:MakeAddConditionWindow() end}
    btnAddAction.OnClick={function() self:MakeAddActionWindow() end}
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
        local stackPanel = MakeComponentPanel(self._triggerPanel)
        local conditionHumanName = SCEN_EDIT.humanExpression(condition, "condition")

        local btnOpenSubNodes = Button:New {
            caption = '+',
            width = SCEN_EDIT.conf.B_HEIGHT,
            height = SCEN_EDIT.conf.B_HEIGHT,
            x = 1,
            height = SCEN_EDIT.conf.B_HEIGHT,
            parent = stackPanel,
            backgroundColor = {0, 0, 0, 0},
            OnClick = {function() 
                self.openedConditionNodes[i] = not self.openedConditionNodes[i]
                self:Populate() 
            end}
        }
        if self.openedConditionNodes[i] then
            btnOpenSubNodes:SetCaption('-')
        end
        local btnEditCondition = Button:New {
            caption = conditionHumanName,
            right = SCEN_EDIT.conf.B_HEIGHT + 10,
            x = SCEN_EDIT.conf.B_HEIGHT + 5,
            height = SCEN_EDIT.conf.B_HEIGHT,
            parent = stackPanel,
            OnClick = {function() self:MakeEditConditionWindow(condition) end}
        }
        local btnRemoveCondition = Button:New {
            caption = "",
            right = 1,
            width = SCEN_EDIT.conf.B_HEIGHT,
            height = SCEN_EDIT.conf.B_HEIGHT,
            parent = stackPanel,
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
        local openedNodes = self.openedConditionNodes[i]
        if openedNodes then
            self:PopulateExpressions(condition, SCEN_EDIT.metaModel.functionTypes[condition.conditionTypeName], 2)
        end
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
        local btnOpenSubNodes = Button:New {
            caption = '+',
            width = SCEN_EDIT.conf.B_HEIGHT,
            height = SCEN_EDIT.conf.B_HEIGHT,
            x = 1,
            height = SCEN_EDIT.conf.B_HEIGHT,
            parent = stackActionPanel,
            backgroundColor = {0, 0, 0, 0},
            OnClick = {function() 
                self.openedActionNodes[i] = not self.openedActionNodes[i]
                self:Populate()
            end}
        }
        if self.openedActionNodes[i] then
            btnOpenSubNodes:SetCaption('-')
        end
        local btnEditAction = Button:New {
            caption = actionHumanName,
            right = SCEN_EDIT.conf.B_HEIGHT + 10,
            x = SCEN_EDIT.conf.B_HEIGHT + 5,
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
        local openedNodes = self.openedActionNodes[i]
        if openedNodes then
            self:PopulateExpressions(action, SCEN_EDIT.metaModel.actionTypes[action.actionTypeName], 2)
        end
    end
end

function TriggerWindow:PopulateExpressions(root, rootType, level)
    for i, input in pairs(rootType.input) do
        local stackPanel = MakeComponentPanel(self._triggerPanel)
        
        local param = root[input.name] or {}
        local paramName = param.name or param.id
        if param.type == 'var' then
            paramName = SCEN_EDIT.model.variableManager:getVariable(param.id).name
        elseif param.type == "expr" then
            local expr = param.expr[1]
            paramName = SCEN_EDIT.metaModel.functionTypes[expr.conditionTypeName].humanName
        elseif type(paramName) == 'table' then
            paramName = "{...}"
        end
        if input.name == "relation" then
            if root.conditionTypeName == "compare_number" then
                paramName = SCEN_EDIT.metaModel.numericComparisonTypes[root.relation.cmpTypeId]
            else
                paramName = SCEN_EDIT.metaModel.identityComparisonTypes[root.relation.cmpTypeId]
            end
        end
        local lblParam = Label:New {
            caption = input.name .. ": " .. (paramName or "nil"),
            x = (level - 1) * 50,
            right = 1,
            parent = stackPanel,
        }

        if param.type == "expr" then
            local expr = param.expr[1]
            local exprType = SCEN_EDIT.metaModel.functionTypes[expr.conditionTypeName]

            self:PopulateExpressions(expr, exprType, level + 1)
        end
        
    end
end

function TriggerWindow:MakeAddConditionWindow()
    return ConditionWindow(self.trigger, self, 'add')
end

function TriggerWindow:MakeEditConditionWindow(condition)
    return ConditionWindow(self.trigger, self, 'edit', condition)
end

function TriggerWindow:MakeRemoveConditionWindow(condition, idx)
    table.remove(self.trigger.conditions, idx)
    self.openedConditionNodes = {}
    self:Populate()
end

function TriggerWindow:MakeAddEventWindow()
    return EventWindow(self.trigger, self, 'add')
end

function TriggerWindow:MakeEditEventWindow(event)
    return EventWindow(self.trigger, self, 'edit', event)
end

function TriggerWindow:MakeRemoveEventWindow(event, idx)
    table.remove(self.trigger.events, idx)
    self:Populate()
end

function TriggerWindow:MakeAddActionWindow()
    return ActionWindow(self.trigger, self, 'add')
end

function TriggerWindow:MakeEditActionWindow(action)
    return ActionWindow(self.trigger, self, 'edit', action)
end

function TriggerWindow:MakeRemoveActionWindow(action, idx)
    table.remove(self.trigger.actions, idx)
    self.openedActionNodes = {}
    self:Populate()
end

