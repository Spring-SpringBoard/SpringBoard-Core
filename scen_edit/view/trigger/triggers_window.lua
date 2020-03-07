SB.Include(Path.Join(SB.DIRS.SRC, 'view/editor.lua'))

TriggersWindow = Editor:extends{}
TriggersWindow:Register({
    name = "triggersWindow",
    tab = "Logic",
    caption = "Triggers",
    tooltip = "Edit triggers",
    image = Path.Join(SB.DIRS.IMG, 'cog.png'),
    order = 1,
})

function TriggersWindow:init()
    self:super("init")

    self.btnAddTrigger = TabbedPanelButton({
        x = 0,
        y = 0,
        tooltip = "Add trigger",
        children = {
            TabbedPanelImage({ file = Path.Join(SB.DIRS.IMG, 'trigger-add.png') }),
            TabbedPanelLabel({ caption = "Add" }),
        },
        OnClick = {
            function()
                self:AddTrigger()
                self.btnAddTrigger:SetPressedState(true)
            end
        },
    })
    self:AddDefaultKeybinding({
        self.btnAddTrigger
    })

    self._triggers = StackPanel:New {
        itemMargin = {0, 0, 0, 0},
        width = "100%",
        autosize = true,
        resizeItems = false,
    }

    local children = {
        ScrollPanel:New {
            x = 0,
            y = 80,
            bottom = 30,
            right = 0,
            borderColor = {0,0,0,0},
            horizontalScrollbar = false,
            children = {
                self._triggers
            },
        },
        self.btnAddTrigger,
    }

    self:Populate()
    SB.model.triggerManager:addListener(TriggerManagerListenerWidget(self))

    self:Finalize(children)
end

function TriggersWindow:AddTrigger()
    local trigger = {
        events = {},
        conditions = {},
        actions = {},
        enabled = true,
    }
    -- generate new trigger name
    local triggers = Table.SortByAttr(SB.model.triggerManager:getAllTriggers(), "name")
    for i = 1, math.huge do
        trigger.name = "Trigger " .. tostring(i)
        local found = false
        for _, t in pairs(triggers) do
            if t.name == trigger.name then
                found = true
                break
            end
        end
        if not found then
            break
        end
    end
    self:MakeTriggerWindow(trigger, false)
--[[    local newTrigger = model:NewTrigger()
    self:Populate()
    for i = 1, #self._triggers.children do
        local panel = self._triggers.children[i]
        if panel.triggerID == newTrigger.id then
            local btnEdit = panel.children[1]
            btnEdit:CallListeners(btnEdit.OnClick)
            return
        end
    end--]]
end

function TriggersWindow:MakeRemoveTriggerWindow(triggerID)
    local cmd = RemoveTriggerCommand(triggerID)
    SB.commandManager:execute(cmd)
end

function TriggersWindow:Populate()
    self._triggers:ClearChildren()
    local triggers = Table.SortByAttr(SB.model.triggerManager:getAllTriggers(), "name")
    for id, trigger in pairs(triggers)  do
        local stackTriggerPanel = MakeComponentPanel(self._triggers)
        stackTriggerPanel.triggerID = trigger.id
        local btnEditTrigger = Button:New {
            caption = trigger.name,
            x = 1,
            right = SB.conf.B_HEIGHT * 2 + 10, --FIXME: figure out how to extend it a bit further
            height = SB.conf.B_HEIGHT,
            _toggle = nil,
            parent = stackTriggerPanel,
            tooltip = "Edit trigger",
        }
        btnEditTrigger.OnClick = {
            function()
                self:MakeTriggerWindow(trigger, true)
            end
        }
        local btnCloneTrigger = Button:New {
            caption = "",
            right = SB.conf.B_HEIGHT + 8,
            width = SB.conf.B_HEIGHT,
            height = SB.conf.B_HEIGHT,
            parent = stackTriggerPanel,
            padding = {0, 0, 0, 0},
            tooltip = "Clone trigger",
            children = {
                Image:New {
                    file = Path.Join(SB.DIRS.IMG, 'trigger-add.png'),
                    height = SB.conf.B_HEIGHT,
                    width = SB.conf.B_HEIGHT,
                    padding = {0, 0, 0, 0},
                    margin = {0, 0, 0, 0},
                },
            },
            OnClick = {
                function()
                    local newTrigger = Table.DeepCopy(trigger)
                    newTrigger.id = nil
                    newTrigger.name = newTrigger.name .. " copy"
                    local cmd = AddTriggerCommand(newTrigger)
                    SB.commandManager:execute(cmd)
                end
            },
        }
        local btnRemoveTrigger = Button:New {
            caption = "",
            right = 0,
            width = SB.conf.B_HEIGHT,
            height = SB.conf.B_HEIGHT,
            parent = stackTriggerPanel,
            padding = {2, 2, 2, 2},
            tooltip = "Remove trigger",
            classname = "negative_button",
            children = {
                Image:New {
                    tooltip = "Remove trigger",
                    file = Path.Join(SB.DIRS.IMG, 'cancel.png'),
                    height = "100%",
                    width = "100%",
                },
            },
            OnClick = {function() self:MakeRemoveTriggerWindow(trigger.id) end},
        }
    end
end

function TriggersWindow:MakeTriggerWindow(trigger, edit)
    local triggerCopy = Table.DeepCopy(trigger)
    local triggerWindow = TriggerWindow(triggerCopy)

    local sw = self.window
    local tw = triggerWindow.window
    tw.x = 500
    tw.y = 500

    SB.SetControlEnabled(sw, false)
    table.insert(tw.OnDispose,
        function()
            SB.SetControlEnabled(sw, true)
            self.btnAddTrigger:SetPressedState(false)
            if not triggerWindow.save then
                return
            end
            local cmd
            if edit then
                cmd = UpdateTriggerCommand(triggerCopy)
            else
                cmd = AddTriggerCommand(triggerWindow.trigger)
            end
            SB.commandManager:execute(cmd)
        end
    )
    return triggerWindow
end

TriggerManagerListenerWidget = TriggerManagerListener:extends{}

function TriggerManagerListenerWidget:init(triggerWindow)
    self.triggerWindow = triggerWindow
end

function TriggerManagerListenerWidget:onTriggerAdded(triggerID)
    self.triggerWindow:Populate()
end

function TriggerManagerListenerWidget:onTriggerRemoved(triggerID)
    self.triggerWindow:Populate()
end

function TriggerManagerListenerWidget:onTriggerUpdated(triggerID)
    self.triggerWindow:Populate()
end
