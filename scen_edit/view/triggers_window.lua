TriggersWindow = Window:Inherit {
    caption = "Trigger window",
    classname = "window",
    minimumSize = {300,200},
    x = 500,
    y = 300,
    _triggers = nil,
}

local this = TriggersWindow 
local inherited = this.inherited

function TriggersWindow:New(obj)
    local btnAddTrigger = Button:New {
        caption='Add trigger',
        width=120,
        x = 1,
        bottom = 1,
        height = SCEN_EDIT.conf.B_HEIGHT,
        OnClick={function() obj:AddTrigger() end}
    }
    local btnClose = Button:New {
        caption='Close',
        width=100,
        x = 130,
        bottom = 1,
        height = SCEN_EDIT.conf.B_HEIGHT,
    }
    obj._triggers = StackPanel:New {
        itemMargin = {0, 0, 0, 0},
        x = 1,
        y = 1,
        right = 1,
        autosize = true,
        resizeItems = false,
    }
    obj.children = {
        ScrollPanel:New {
            x = 1,
            y = 15,
            right = 5,
            bottom = SCEN_EDIT.conf.C_HEIGHT * 2,
            children = { 
                obj._triggers
            },
        },
        btnAddTrigger,
        btnClose,
    }
    btnClose.OnClick={
        function() 
            obj:Dispose() 
        end
    }
    obj = inherited.New(self, obj)
    obj:Populate()
    local triggerManagerListener = TriggerManagerListenerWidget(obj)
    SCEN_EDIT.model.triggerManager:addListener(triggerManagerListener)
    obj.OnDispose = {
        function()
            SCEN_EDIT.model.triggerManager:removeListener(triggerManagerListener)
        end
    }
    return obj
end

function TriggersWindow:AddTrigger()
    local trigger = { 
        name = "New trigger",
        events = {},
        conditions = {},
        actions = {},
        enabled = true,
    }
    self:MakeTriggerWindow(trigger, false)
--[[    local newTrigger = model:NewTrigger()
    self:Populate()
    for i = 1, #self._triggers.children do
        local panel = self._triggers.children[i]
        if panel.triggerId == newTrigger.id then
            local btnEdit = panel.children[1]
            btnEdit:CallListeners(btnEdit.OnClick)
            return
        end
    end--]]
end

function TriggersWindow:MakeRemoveTriggerWindow(triggerId)
    local cmd = RemoveTriggerCommand(triggerId)
    SCEN_EDIT.commandManager:execute(cmd)
end

function TriggersWindow:Populate()
    self._triggers:ClearChildren()
    local triggers = SortByName(SCEN_EDIT.model.triggerManager:getAllTriggers(), "name")
    for id, trigger in pairs(triggers)  do        
        local stackTriggerPanel = MakeComponentPanel(self._triggers)
        stackTriggerPanel.triggerId = trigger.id
        local btnEditTrigger = Button:New {
            caption = trigger.name,
            x = 1, 
            right = SCEN_EDIT.conf.B_HEIGHT * 2 + 10, --FIXME: figure out how to extend it a bit further
            height = SCEN_EDIT.conf.B_HEIGHT,
            _toggle = nil,
            parent = stackTriggerPanel,
        }
        local btnCloneTrigger = Button:New {
            caption = "",
            right = SCEN_EDIT.conf.B_HEIGHT + 8,
            width = SCEN_EDIT.conf.B_HEIGHT,
            height = SCEN_EDIT.conf.B_HEIGHT,
            parent = stackTriggerPanel,
            padding = {0, 0, 0, 0},
            children = {
                Image:New { 
                    tooltip = "Clone trigger", 
                    file=SCEN_EDIT_IMG_DIR .. "clone.png", 
                    height = SCEN_EDIT.conf.B_HEIGHT, 
                    width = SCEN_EDIT.conf.B_HEIGHT,
                    padding = {0, 0, 0, 0},
                    margin = {0, 0, 0, 0},
                },
            },
            OnClick = {
                function() 
                    local newTrigger = SCEN_EDIT.deepcopy(trigger)
                    newTrigger.id = nil
                    newTrigger.name = newTrigger.name .. " copy"
                    local cmd = AddTriggerCommand(newTrigger)
                    SCEN_EDIT.commandManager:execute(cmd)
                end
            },
        }
        local btnRemoveTrigger = Button:New {
            caption = "",
            right = 1,
            width = SCEN_EDIT.conf.B_HEIGHT,
            height = SCEN_EDIT.conf.B_HEIGHT,
            parent = stackTriggerPanel,
            padding = {0, 0, 0, 0},
            children = {
                Image:New { 
                    tooltip = "Remove trigger", 
                    file=SCEN_EDIT_IMG_DIR .. "list-remove.png", 
                    height = SCEN_EDIT.conf.B_HEIGHT, 
                    width = SCEN_EDIT.conf.B_HEIGHT,
                    padding = {0, 0, 0, 0},
                    margin = {0, 0, 0, 0},
                },
            },
            OnClick = {function() self:MakeRemoveTriggerWindow(trigger.id) end},
        }
            
        btnEditTrigger.OnClick = {
            function() 
                local newWin = self:MakeTriggerWindow(trigger, true)
            end
        }
    end
end

function TriggersWindow:MakeTriggerWindow(trigger, edit) 
    local triggerWindow = TriggerWindow:New {
         parent = self.parent,
        trigger = trigger,
    }
    if self.x + self.width + triggerWindow.width > self.parent.width then
        triggerWindow.x = self.x - triggerWindow.width
    else
        triggerWindow.x = self.x + self.width
    end
    triggerWindow.y = self.y

    self.disableChildrenHitTest = true
    table.insert(triggerWindow.OnDispose, 
        function()
--            btnEditTrigger:SetCaption(trigger.name)
            self.disableChildrenHitTest = false
            local cmd = nil
            if edit then
                cmd = UpdateTriggerCommand(trigger)
            else
                cmd = AddTriggerCommand(triggerWindow.trigger)
            end
            SCEN_EDIT.commandManager:execute(cmd)
        end
    )
    return triggerWindow
end
