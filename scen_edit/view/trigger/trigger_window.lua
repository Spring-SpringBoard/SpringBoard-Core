SB_VIEW_TRIGGER_PANELS_DIR = Path.Join(SB_VIEW_TRIGGER_DIR, "panels/")
SB.IncludeDir(SB_VIEW_TRIGGER_PANELS_DIR)

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
        height = SB.conf.B_HEIGHT,
        backgroundColor = SB.conf.BTN_ADD_COLOR,
        tooltip = "Add event",
    }
    local btnAddCondition = Button:New {
        caption='+ Condition',
        width=120,
        x = 120,
        bottom = 1,
        height = SB.conf.B_HEIGHT,
        backgroundColor = SB.conf.BTN_ADD_COLOR,
        tooltip = "Add condition",
    }
    local btnAddAction = Button:New {
        caption='+ Action',
        width=110,
        x = 250,
        bottom = 1,
        height = SB.conf.B_HEIGHT,
        backgroundColor = SB.conf.BTN_ADD_COLOR,
        tooltip = "Add action",
    }
    local btnOk = Button:New {
        caption='OK',
        width=100,
        x = 370,
        bottom = 1,
        height = SB.conf.B_HEIGHT,
        backgroundColor = SB.conf.BTN_OK_COLOR,
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
        height = SB.conf.B_HEIGHT,
        backgroundColor = SB.conf.BTN_CANCEL_COLOR,
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
                y = 15 + SB.conf.B_HEIGHT,
                right = 5,
                bottom = SB.conf.B_HEIGHT * 2,
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
        height = SB.conf.C_HEIGHT,
        align = 'center',
        parent = self._triggerPanel,
    }
    for i = 1, #self.trigger.events do
        local event = self.trigger.events[i]
        local stackEventPanel = MakeComponentPanel(self._triggerPanel)
        local btnEditEvent = Button:New {
            caption = SB.model.triggerManager:GetSafeEventHumanName(trigger, event),
            right = SB.conf.B_HEIGHT + 10,
            x = 1,
            height = SB.conf.B_HEIGHT,
            parent = stackEventPanel,
            tooltip = "Edit event",
            OnClick = {function() self:MakeEditEventWindow(event) end},
        }
        local btnRemoveEvent = Button:New {
            caption = "",
            right = 1,
            width = SB.conf.B_HEIGHT,
            height = SB.conf.B_HEIGHT,
            parent = stackEventPanel,
            padding = {0, 0, 0, 0},
            children = {
                Image:New {
                    tooltip = "Remove event",
                    file=SB_IMG_DIR .. "list-remove.png",
                    height = SB.conf.B_HEIGHT,
                    width = SB.conf.B_HEIGHT,
                    margin = {0, 0, 0, 0},
                },
            },
            tooltip = "Remove event",
            OnClick = {function() self:MakeRemoveEventWindow(event, i) end}
        }
    end
    local conditionLabel = Label:New {
        caption = "- Conditions -",
        height = SB.conf.C_HEIGHT,
        align = 'center',
        vlign = 'center',
        parent = self._triggerPanel,
    }
    for i = 1, #self.trigger.conditions do
        local condition = self.trigger.conditions[i]
        local stackPanel = MakeComponentPanel(self._triggerPanel)
        local conditionHumanName = SB.humanExpression(condition, "condition")

        local btnOpenSubNodes = Button:New {
            caption = '+',
            width = SB.conf.B_HEIGHT,
            height = SB.conf.B_HEIGHT,
            x = 1,
            height = SB.conf.B_HEIGHT,
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
            right = SB.conf.B_HEIGHT + 10,
            x = SB.conf.B_HEIGHT + 5,
            height = SB.conf.B_HEIGHT,
            parent = stackPanel,
            tooltip = "Edit condition",
            OnClick = {function() self:MakeEditConditionWindow(condition) end}
        }
        local btnRemoveCondition = Button:New {
            caption = "",
            right = 1,
            width = SB.conf.B_HEIGHT,
            height = SB.conf.B_HEIGHT,
            parent = stackPanel,
            padding = {0, 0, 0, 0},
            tooltip = "Remove condition",
            children = {
                Image:New {
                    tooltip = "Remove condition",
                    file=SB_IMG_DIR .. "list-remove.png",
                    height = SB.conf.B_HEIGHT,
                    width = SB.conf.B_HEIGHT,
                    margin = {0, 0, 0, 0},
                },
            },
            OnClick = {function() self:MakeRemoveConditionWindow(condition, i) end}
        }
        local openedNodes = self.openedConditionNodes[i]
        if openedNodes then
            self:PopulateExpressions(condition, SB.metaModel.functionTypes[condition.typeName], 2, condition.typeName)
        end
    end
    local actionLabel = Label:New {
        caption = "- Actions -",
        height = SB.conf.C_HEIGHT,
        align = 'center',
        parent = self._triggerPanel,
    }
    for i = 1, #self.trigger.actions do
        local action = self.trigger.actions[i]
        local stackActionPanel = MakeComponentPanel(self._triggerPanel)
        local actionHumanName = SB.humanExpression(action, "action")
        local btnOpenSubNodes = Button:New {
            caption = '+',
            width = SB.conf.B_HEIGHT,
            height = SB.conf.B_HEIGHT,
            x = 1,
            height = SB.conf.B_HEIGHT,
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
            right = SB.conf.B_HEIGHT + 10,
            x = SB.conf.B_HEIGHT + 5,
            height = SB.conf.B_HEIGHT,
            parent = stackActionPanel,
            tooltip = "Edit action",
            OnClick = {function() self:MakeEditActionWindow(action) end}
        }
        local btnRemoveAction = Button:New {
            caption = "",
            right = 1,
            width = SB.conf.B_HEIGHT,
            height = SB.conf.B_HEIGHT,
            parent = stackActionPanel,
            padding = {0, 0, 0, 0},
            tooltip = "Remove action",
            children = {
                Image:New {
                    tooltip = "Remove action",
                    file= SB_IMG_DIR .. "list-remove.png",
                    height = SB.conf.B_HEIGHT,
                    width = SB.conf.B_HEIGHT,
                    margin = {0, 0, 0, 0},
                },
            },
            OnClick = {function() self:MakeRemoveActionWindow(action, i) end},
        }
        local openedNodes = self.openedActionNodes[i]
        if openedNodes then
            self:PopulateExpressions(action, SB.metaModel.actionTypes[action.typeName], 2, action.typeName)
        end
    end
end

function TriggerWindow:PopulateExpressions(root, rootType, level, typeName)
    if rootType == nil then
        local stackPanel = MakeComponentPanel(self._triggerPanel)
        local lblParam = Label:New {
            caption = "Error: Cannot find declaration for type: " ..typeName,
            x = (level - 1) * 50,
            right = 1,
            parent = stackPanel,
        }
        return
    end
    for i, input in pairs(rootType.input) do
        local stackPanel = MakeComponentPanel(self._triggerPanel)

        local param = root[input.name] or {}
        local paramName = param.name or param.value
        if param.type == 'var' then
            paramName = SB.model.variableManager:getVariable(param.value).name
        elseif param.type == "expr" then
            local expr = param.expr[1]
            paramName = SB.metaModel.functionTypes[expr.typeName].humanName
        elseif type(paramName) == 'table' then
            paramName = "{...}"
        end
        if input.name == "relation" then
            if root.typeName == "compare_number" then
                paramName = SB.metaModel.numericComparisonTypes[root.relation.cmpTypeId]
            else
                paramName = SB.metaModel.identityComparisonTypes[root.relation.cmpTypeId]
            end
        end
        local lblParam = Label:New {
            caption = input.name .. ": " .. (tostring(paramName) or "nil"),
            x = (level - 1) * 50,
            right = 1,
            parent = stackPanel,
        }

        if param.type == "expr" then
            local expr = param.expr[1]
            local exprType = SB.metaModel.functionTypes[expr.typeName]

            self:PopulateExpressions(expr, exprType, level + 1, expr.typeName)
        end
    end
end

function TriggerWindow:_GetTriggerElementWindowParams()
    return {
        trigger = self.trigger,
        params = SB.model.triggerManager:GetTriggerScopeParams(self.trigger),
        parentWindow = self.window,
        triggerWindow = self,
    }
end

function TriggerWindow:MakeAddConditionWindow()
    local opts = self:_GetTriggerElementWindowParams()
    opts.mode = 'add'
    return ConditionWindow(opts)
end

function TriggerWindow:MakeEditConditionWindow(condition)
    local opts = self:_GetTriggerElementWindowParams()
    opts.mode = 'edit'
    opts.condition = condition
    return ConditionWindow(opts)
end

function TriggerWindow:MakeRemoveConditionWindow(condition, idx)
    table.remove(self.trigger.conditions, idx)
    self.openedConditionNodes = {}
    self:Populate()
end

function TriggerWindow:MakeAddEventWindow()
    local opts = self:_GetTriggerElementWindowParams()
    opts.mode = 'add'
    return EventWindow(opts)
end

function TriggerWindow:MakeEditEventWindow(event)
    local opts = self:_GetTriggerElementWindowParams()
    opts.mode = 'edit'
    opts.event = event
    return EventWindow(opts)
end

function TriggerWindow:MakeRemoveEventWindow(event, idx)
    table.remove(self.trigger.events, idx)
    self:Populate()
end

function TriggerWindow:MakeAddActionWindow()
    local opts = self:_GetTriggerElementWindowParams()
    opts.mode = 'add'
    return ActionWindow(opts)
end

function TriggerWindow:MakeEditActionWindow(action)
    local opts = self:_GetTriggerElementWindowParams()
    opts.mode = 'edit'
    opts.action = action
    return ActionWindow(opts)
end

function TriggerWindow:MakeRemoveActionWindow(action, idx)
    table.remove(self.trigger.actions, idx)
    self.openedActionNodes = {}
    self:Populate()
end
