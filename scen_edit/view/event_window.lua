EventWindow = Window:Inherit {
    classname = "window",    
    resizable = false,
    clientWidth = 300,
    clientHeight = 100,
    x = 500,
    y = 300,
    trigger = nil, --required
    triggerWindow = nil, --required
    mode = nil, --'add' or 'edit'
}

local this = EventWindow 
local inherited = this.inherited

function EventWindow:New(obj)
    obj.triggerWindow.disableChildrenHitTest = true    
    obj.btnOk = Button:New {
        caption = "OK",
        height = SCEN_EDIT.conf.B_HEIGHT,
        width = "40%",
        x = "5%",
        y = "20%",
    }
    obj.btnCancel = Button:New {
        caption = "Cancel",
        height = SCEN_EDIT.conf.B_HEIGHT,
        width = "40%",
        x = "55%",
        y = "20%",
    }
    obj.cmbEventTypes = ComboBox:New {
        items = GetField(SCEN_EDIT.metaModel.eventTypes, "humanName"),
        eventTypes = GetField(SCEN_EDIT.metaModel.eventTypes, "name"),
        height = SCEN_EDIT.conf.B_HEIGHT,
        width = "40%",
        y = "60%",
        x = '30%',
    }
    obj.children = {
        obj.cmbEventTypes,
        obj.btnOk,
        obj.btnCancel,
    }
    
    obj = inherited.New(self, obj)

    obj.btnCancel.OnClick = {
        function() 
            obj.triggerWindow.disableChildrenHitTest = false
            obj:Dispose()
        end
    }
    
    obj.btnOk.OnClick = {
        function()            
            if obj.mode == 'edit' then
                obj:EditEvent()
                obj.triggerWindow.disableChildrenHitTest = false
                obj:Dispose()
            elseif obj.mode == 'add' then
                obj:AddEvent()
                obj.triggerWindow.disableChildrenHitTest = false
                obj:Dispose()
            end
        end
    }
    
    if obj.mode == 'add' then
        obj.caption = "New event for - " .. obj.trigger.name
        local tw = obj.triggerWindow
        obj.x = tw.x
        obj.y = tw.y + tw.height + 5
        if tw.parent.height <= obj.y + obj.height then
            obj.y = tw.y - obj.height
        end
    elseif obj.mode == 'edit' then
        obj.cmbEventTypes:Select(GetIndex(obj.cmbEventTypes.eventTypes, obj.event.eventTypeName))
        obj.caption = "Edit event for trigger " .. obj.trigger.name
        local tw = obj.triggerWindow
        if tw.x + tw.width + obj.width > tw.parent.width then
            obj.x = tw.x - obj.width
        else
            obj.x = tw.x + tw.width
        end
        obj.y = tw.y
    end
    
    return obj
end

function EventWindow:EditEvent()
    self.event.eventTypeName = self.cmbEventTypes.eventTypes[self.cmbEventTypes.selected]
    self.triggerWindow:Populate()
end

function EventWindow:AddEvent()
    local event = { eventTypeName = self.cmbEventTypes.eventTypes[self.cmbEventTypes.selected] }
    table.insert(self.trigger.events, event)
    self.triggerWindow:Populate()
end


