SB.Include(Path.Join(SB_VIEW_DIR, "editor.lua"))

SB_VIEW_TRIGGER_FIELDS_DIR = Path.Join(SB_VIEW_TRIGGER_DIR, "fields/")
SB.IncludeDir(SB_VIEW_TRIGGER_FIELDS_DIR)

TriggerWindow = Editor:extends{}

function TriggerWindow:init(trigger)
    Editor.init(self)

    self.trigger = trigger
    self.openedConditionNodes = {}
    self.openedActionNodes = {}

    self:AddField(StringField({
        name = "name",
        title = "Name:",
        tooltip = "Trigger name",
        value = self.trigger.name,
    }))

    self._triggerPanel = StackPanel:New {
        itemMargin = {0, 0, 0, 0},
        x = 0,
        y = 0,
        right = 0,
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
        classname = "positive_button",
        tooltip = "Add event",
    }
    local btnAddCondition = Button:New {
        caption='+ Condition',
        width=120,
        x = 120,
        bottom = 1,
        height = SB.conf.B_HEIGHT,
        classname = "positive_button",
        tooltip = "Add condition",
    }
    local btnAddAction = Button:New {
        caption='+ Action',
        width=110,
        x = 250,
        bottom = 1,
        height = SB.conf.B_HEIGHT,
        classname = "positive_button",
        tooltip = "Add action",
    }
    local btnOK = Button:New {
        caption='OK',
        width=100,
        x = 370,
        bottom = 1,
        height = SB.conf.B_HEIGHT,
        classname = "option_button",
        OnClick = {
            function()
                self:ConfirmDialog()
            end
        }
    }
    local btnCancel = Button:New {
        caption='Cancel',
        width=100,
        x = 480,
        bottom = 1,
        height = SB.conf.B_HEIGHT,
        classname = "negative_button",
        OnClick={function() self.window:Dispose() end}
    }

    local children = {
        btnAddEvent,
        btnAddCondition,
        btnAddAction,
        btnOK,
        btnCancel,
    }

    table.insert(children,
        ScrollPanel:New {
            x = 0,
            y = 0,
            bottom = 30,
            right = 0,
            borderColor = {0,0,0,0},
            horizontalScrollbar = false,
            children = { self.stackPanel },
        }
    )
    table.insert(children,
        ScrollPanel:New {
            x = 0,
            y = 50,
            bottom = 30,
            right = 0,
            borderColor = {0,0,0,0},
            horizontalScrollbar = false,
            children = { self._triggerPanel },
        }
    )
    self:Finalize(children, {
        notMainWindow = true,
        noCloseButton = true,
        width = 610,
        height = 350,
        x = tostring(math.random(35, 45)) .. "%",
        y = tostring(math.random(35, 45)) .. "%",
    })

    self:Populate()

    btnAddEvent.OnClick={function() self:MakeAddEventWindow() end}
    btnAddCondition.OnClick={function() self:MakeAddConditionWindow() end}
    btnAddAction.OnClick={function() self:MakeAddActionWindow() end}
end

function TriggerWindow:ConfirmDialog()
    self.trigger.name = self.fields["name"].value
    self.save = true
    self.window:Dispose()
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
            right = 0,
            width = SB.conf.B_HEIGHT,
            height = SB.conf.B_HEIGHT,
            parent = stackEventPanel,
            padding = {2, 2, 2, 2},
            tooltip = "Remove event",
            classname = "negative_button",
            children = {
                Image:New {
                    file = SB_IMG_DIR .. "cancel.png",
                    height = "100%",
                    width = "100%",
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
            right = 0,
            width = SB.conf.B_HEIGHT,
            height = SB.conf.B_HEIGHT,
            parent = stackPanel,
            padding = {2, 2, 2, 2},
            tooltip = "Remove condition",
            classname = "negative_button",
            children = {
                Image:New {
                    file = SB_IMG_DIR .. "cancel.png",
                    height = "100%",
                    width = "100%",
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
            right = 0,
            width = SB.conf.B_HEIGHT,
            height = SB.conf.B_HEIGHT,
            parent = stackActionPanel,
            padding = {2, 2, 2, 2},
            tooltip = "Remove action",
            classname = "negative_button",
            children = {
                Image:New {
                    file = SB_IMG_DIR .. "cancel.png",
                    height = "100%",
                    width = "100%",
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
        local paramName = param.value
        if param.type == 'var' then
            paramName = SB.model.variableManager:getVariable(param.value).name
        elseif param.type == "expr" then
            local expr = param.value
            paramName = SB.metaModel.functionTypes[expr.typeName].humanName
        elseif type(paramName) == 'table' then
            paramName = SB.humanExpression(param, "value", input.type)
        end
        if input.name == "relation" then
            if root.typeName == "compare_number" then
                paramName = SB.metaModel.numericComparisonTypes[root.relation.value]
            else
                paramName = SB.metaModel.identityComparisonTypes[root.relation.value]
            end
        end
        local lblParam = Label:New {
            caption = input.name .. ": " .. (tostring(paramName) or "nil"),
            x = (level - 1) * 50,
            right = 1,
            parent = stackPanel,
        }

        if param.type == "expr" then
            local expr = param.value
            local exprType = SB.metaModel.functionTypes[expr.typeName]

            self:PopulateExpressions(expr, exprType, level + 1, expr.typeName)
        end
    end
end

function TriggerWindow:_GetTriggerElementWindowParams()
    return {
        trigger = self.trigger,
        params = SB.model.triggerManager:GetTriggerScopeParams(self.trigger),
    }
end

function TriggerWindow:_PostElementWindowCreate(elementWindow)
    SB.MakeWindowModal(elementWindow.window, self.window)
    return elementWindow
end

function TriggerWindow:MakeAddConditionWindow()
    local opts = self:_GetTriggerElementWindowParams()
    opts.mode = 'add'
    opts.OnConfirm = {
        function(element)
            table.insert(self.trigger.conditions, element)
            self:Populate()
        end
    }
    return self:_PostElementWindowCreate(ConditionWindow(opts))
end

function TriggerWindow:MakeEditConditionWindow(condition)
    local opts = self:_GetTriggerElementWindowParams()
    opts.mode = 'edit'
    opts.condition = condition
    opts.OnConfirm = {
        function(element)
            self:Populate()
        end
    }
    return self:_PostElementWindowCreate(ConditionWindow(opts))
end

function TriggerWindow:MakeRemoveConditionWindow(condition, idx)
    table.remove(self.trigger.conditions, idx)
    self.openedConditionNodes = {}
    self:Populate()
end

function TriggerWindow:MakeAddEventWindow()
    local opts = self:_GetTriggerElementWindowParams()
    opts.mode = 'add'
    opts.OnConfirm = {
        function(element)
            table.insert(self.trigger.events, element)
            self:Populate()
        end
    }
    return self:_PostElementWindowCreate(EventWindow(opts))
end

function TriggerWindow:MakeEditEventWindow(event)
    local opts = self:_GetTriggerElementWindowParams()
    opts.mode = 'edit'
    opts.event = event
    opts.OnConfirm = {
        function(element)
            self:Populate()
        end
    }
    return self:_PostElementWindowCreate(EventWindow(opts))
end

function TriggerWindow:MakeRemoveEventWindow(event, idx)
    table.remove(self.trigger.events, idx)
    self:Populate()
end

-- Merge additional params from other, previous actions
-- FIXME: Maybe this should be moved to the triggerManager
function TriggerWindow:_MergeExtraActionParams(opts, action)
    for _, a in ipairs(self.trigger.actions) do
        -- Do not include actions *after* this action
        if a == action then
            break
        end

        local aType = SB.metaModel.actionTypes[a.typeName]
        for _, param in pairs(aType.param) do
            table.insert(opts.params, {
                name = param.name,
                type = param.type,
                humanName = "Action(" .. aType.humanName .. "): " .. param.name,
            })
        end
    end
end

function TriggerWindow:MakeAddActionWindow()
    local opts = self:_GetTriggerElementWindowParams()
    self:_MergeExtraActionParams(opts)
    opts.mode = 'add'
    opts.OnConfirm = {
        function(element)
            table.insert(self.trigger.actions, element)
            self:Populate()
        end
    }
    return self:_PostElementWindowCreate(ActionWindow(opts))
end

function TriggerWindow:MakeEditActionWindow(action)
    local opts = self:_GetTriggerElementWindowParams()
    self:_MergeExtraActionParams(opts, action)
    opts.mode = 'edit'
    opts.action = action
    opts.OnConfirm = {
        function(element)
            self:Populate()
        end
    }
    return self:_PostElementWindowCreate(ActionWindow(opts))
end

function TriggerWindow:MakeRemoveActionWindow(action, idx)
    table.remove(self.trigger.actions, idx)
    self.openedActionNodes = {}
    self:Populate()
end
