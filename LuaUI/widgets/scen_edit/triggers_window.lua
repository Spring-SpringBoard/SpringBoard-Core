local Chili = WG.Chili
local C_HEIGHT = 16
local B_HEIGHT = 26
local SCENEDIT_IMG_DIR = LUAUI_DIRNAME .. "images/scenedit/"

TriggersWindow = Chili.Window:Inherit {
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
    local btnAddTrigger = Chili.Button:New {
        caption='Add trigger',
        width='40%',
        x = 1,
        bottom = 1,
        height = B_HEIGHT,
        OnClick={function() obj:AddTrigger() end}
    }
    local btnClose = Chili.Button:New {
        caption='Close',
        width='40%',
        x = '50%',
        bottom = 1,
        height = B_HEIGHT,
    }
    obj._triggers = Chili.StackPanel:New {
        itemMargin = {0, 0, 0, 0},
        x = 1,
        y = 1,
        right = 1,
        autosize = true,
        resizeItems = false,
    }
    obj.children = {
        Chili.ScrollPanel:New {
            x = 1,
            y = 15,
            right = 5,
            bottom = C_HEIGHT * 2,
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
    local triggers = SCEN_EDIT.model.triggerManager:getAllTriggers()
    for id, trigger in pairs(triggers)  do		
        local stackTriggerPanel = Chili.StackPanel:New {
            triggerId = trigger.id,
            parent = self._triggers,
            width = "100%",
            height = B_HEIGHT + 8,
            orientation = "horizontal",
            padding = {0, 0, 0, 0},
            itemMarging = {0, 0, 0, 0},
            resizeItems = false,
        }
        local btnEditTrigger = Chili.Button:New {
            caption = trigger.name,
            right = B_HEIGHT + 10,
            x = 1,
            height = B_HEIGHT,
            _toggle = nil,
            parent = stackTriggerPanel,
        }
        local btnRemoveTrigger = Chili.Button:New {
            caption = "",
            right = 1,
            width = B_HEIGHT,
            height = B_HEIGHT,
            parent = stackTriggerPanel,
            padding = {0, 0, 0, 0},
            children = {
                Chili.Image:New { 
                    tooltip = "Remove trigger", 
                    file=SCENEDIT_IMG_DIR .. "list-remove.png", 
                    height = B_HEIGHT, 
                    width = B_HEIGHT,
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
