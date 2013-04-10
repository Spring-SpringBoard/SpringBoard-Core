local C_HEIGHT = 16
local B_HEIGHT = 24

DebugTriggerView = TriggerManagerListener:extends{}

function DebugTriggerView:init(parent)
    self.parent = parent
    self:Populate()
    SCEN_EDIT.model.triggerManager:addListener(self)
end

function DebugTriggerView:Populate()
    self.parent:ClearChildren()
    local triggers = SCEN_EDIT.model.triggerManager:getAllTriggers()
    for id, trigger in pairs(triggers)  do        
        local triggerPanel = MakeComponentPanel(self.parent)
        local maxChars = 15
        local cbTriggerName = Checkbox:New {
            caption = trigger.name:sub(1, maxChars),
            width = 110,
            x = 1,
            parent = triggerPanel,
            checked = trigger.enabled,
            OnChange = {
                function(cbToggled, checked)
                    trigger.enabled = checked
                    local cmd = UpdateTriggerCommand(trigger)
                    SCEN_EDIT.commandManager:execute(cmd)
                end
            },
        }
        local btnExecuteTrigger = Button:New {
            caption = "Execute",
            right = B_HEIGHT + 120,
            width = 100,
--            x = 110,
            height = B_HEIGHT,
            parent = triggerPanel,
            OnClick = {
                function()
                    local cmd = ExecuteTriggerCommand(trigger.id)
                    SCEN_EDIT.commandManager:execute(cmd)
                end
            },
        }
        local btnExecuteTriggerActions = Button:New {
            caption = "Execute actions",
            right = 1,
            width = 120,
            height = B_HEIGHT,
            parent = triggerPanel,
            OnClick = {
                function() 
                    local cmd = ExecuteTriggerActionsCommand(trigger.id)
                    SCEN_EDIT.commandManager:execute(cmd)
                end
            },
        }
    end
end

function DebugTriggerView:Dispose()
    SCEN_EDIT.model.triggerManager:removeListener(self)
end

function DebugTriggerView:onTriggerAdded(triggerId)
    self:Populate()
end

function DebugTriggerView:onTriggerRemoved(triggerId)
    self:Populate()
end

function DebugTriggerView:onTriggerUpdated(triggerId)
    self:Populate()
end
