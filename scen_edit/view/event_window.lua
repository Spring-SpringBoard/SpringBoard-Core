EventWindow = LCS.class{}

function EventWindow:init(trigger, triggerWindow, mode, event)
    self.trigger = trigger
    self.triggerWindow = triggerWindow
    self.mode = mode
    self.event = event

    SCEN_EDIT.SetControlEnabled(self.triggerWindow.window, false)
    self.btnOk = Button:New {
        caption = "OK",
        height = SCEN_EDIT.conf.B_HEIGHT,
        width = "40%",
        x = "5%",
        y = "20%",
        backgroundColor = SCEN_EDIT.conf.BTN_OK_COLOR,
    }
    self.btnCancel = Button:New {
        caption = "Cancel",
        height = SCEN_EDIT.conf.B_HEIGHT,
        width = "40%",
        x = "55%",
        y = "20%",
        backgroundColor = SCEN_EDIT.conf.BTN_CANCEL_COLOR,
    }
    self.cmbEventTypes = ComboBox:New {
        items = GetField(SCEN_EDIT.metaModel.eventTypes, "humanName"),
        eventTypes = GetField(SCEN_EDIT.metaModel.eventTypes, "name"),
        height = SCEN_EDIT.conf.B_HEIGHT,
        width = "40%",
        y = "60%",
        x = '30%',
    }

    self.window = Window:New {
        resizable = false,
        clientWidth = 300,
        clientHeight = 100,
        x = 500,
        y = 300,
        parent = screen0,
        children = {
            self.cmbEventTypes,
            self.btnOk,
            self.btnCancel,
        }
    }

    self.btnCancel.OnClick = {
        function() 
            SCEN_EDIT.SetControlEnabled(self.triggerWindow.window, true)
            self.window:Dispose()
        end
    }
    
    self.btnOk.OnClick = {
        function()            
            if self.mode == 'edit' then
                self:EditEvent()
                SCEN_EDIT.SetControlEnabled(self.triggerWindow.window, true)
                self.window:Dispose()
            elseif self.mode == 'add' then
                self:AddEvent()
                SCEN_EDIT.SetControlEnabled(self.triggerWindow.window, true)
                self.window:Dispose()
            end
        end
    }
    
    local tw = self.triggerWindow.window
    local sw = self.window
    if self.mode == 'add' then
        sw.caption = "New event for - " .. self.trigger.name
        sw.x = tw.x
        sw.y = tw.y + tw.height + 5
        if tw.parent.height <= sw.y + sw.height then
            sw.y = tw.y - sw.height
        end
    elseif self.mode == 'edit' then
        self.cmbEventTypes:Select(GetIndex(self.cmbEventTypes.eventTypes, self.event.eventTypeName))
        sw.caption = "Edit event for trigger " .. self.trigger.name
        if tw.x + tw.width + sw.width > tw.parent.width then
            sw.x = tw.x - sw.width
        else
            sw.x = tw.x + tw.width
        end
        sw.y = tw.y
    end
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


