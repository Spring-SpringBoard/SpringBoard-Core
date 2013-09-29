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
        local maxChars = 8
		shortName = trigger.name:sub(1, maxChars)
		if #trigger.name > 8 then
			shortName = shortName .. "..."
		end
        local cbTriggerName = Checkbox:New {
            caption = shortName,
            width = 80,
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
            caption = "Run",
            right = 90,
            width = 60,
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
            caption = "Run actions",
            right = 1,
            width = 80,
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
