TriggersWindow = LCS.class{}

function TriggersWindow:init()
    local btnAddTrigger = Button:New {
        caption='+ Trigger',
        width=120,
        x = 1,
        bottom = 1,
        height = SCEN_EDIT.conf.B_HEIGHT,
        OnClick={function() self:AddTrigger() end},
        backgroundColor = SCEN_EDIT.conf.BTN_ADD_COLOR,
    }
    local btnClose = Button:New {
        caption='Close',
        width=100,
        x = 130,
        bottom = 1,
        height = SCEN_EDIT.conf.B_HEIGHT,
        OnClick = { function() self.window:Dispose() end },
    }
    self._triggers = StackPanel:New {
        itemMargin = {0, 0, 0, 0},
        width = "100%",
        autosize = true,
        resizeItems = false,
    }

    self.window = Window:New {
        caption = "Trigger",
        minimumSize = {300,200},
        x = 100,
        y = 180,
        parent = screen0,
        children = {
            ScrollPanel:New {
                y = 15,
                width = "100%",
                bottom = SCEN_EDIT.conf.C_HEIGHT * 2,
                children = { 
                    self._triggers
                },
            },
            btnAddTrigger,
            btnClose,
        }
    }

    self:Populate()
    local triggerManagerListener = TriggerManagerListenerWidget(self)
    SCEN_EDIT.model.triggerManager:addListener(triggerManagerListener)
    self.window.OnDispose = {
        function()
            SCEN_EDIT.model.triggerManager:removeListener(triggerManagerListener)
        end
    }
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
        btnEditTrigger.OnClick = {
            function()
                local newWin = self:MakeTriggerWindow(trigger, true)
            end
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
    end
end

function TriggersWindow:MakeTriggerWindow(trigger, edit) 
    local triggerCopy = SCEN_EDIT.deepcopy(trigger)
    local triggerWindow = TriggerWindow(triggerCopy)

    local sw = self.window
    local tw = triggerWindow.window
    if sw.x + sw.width + tw.width > sw.parent.width then
        tw.x = sw.x - tw.width
    else
        tw.x = sw.x + sw.width
    end
    tw.y = sw.y

    SCEN_EDIT.SetControlEnabled(sw, false)
    table.insert(tw.OnDispose, 
        function()
            SCEN_EDIT.SetControlEnabled(sw, true)
			if not triggerWindow.save then
				return
			end
            local cmd = nil
            if edit then
                cmd = UpdateTriggerCommand(triggerCopy)
            else
                cmd = AddTriggerCommand(triggerWindow.trigger)
            end
            SCEN_EDIT.commandManager:execute(cmd)
        end
    )
    return triggerWindow
end
