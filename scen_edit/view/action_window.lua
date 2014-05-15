ActionWindow = LCS.class{}

function ActionWindow:init(trigger, triggerWindow, mode, action)
    self.trigger = trigger
    self.triggerWindow = triggerWindow
    self.mode = mode
    self.action = action

    self.triggerWindow.window.disableChildrenHitTest = true    
    self.btnOk = Button:New {
        caption = "OK",
        height = SCEN_EDIT.conf.B_HEIGHT,
        width = "40%",
        x = "5%",
        y = "7%",
    }
    self.btnCancel = Button:New {
        caption = "Cancel",
        height = SCEN_EDIT.conf.B_HEIGHT,
        width = "40%",
        x = "55%",
        y = "7%",
    }    
    self.actionPanel = StackPanel:New {
        itemMargin = {0, 0, 0, 0},
        x = 1,
        y = 1,
        right = 1,
        autosize = true,
        resizeItems = false,
        padding = {0, 0, 0, 0}
    }
    self.validActions = SortByName(SCEN_EDIT.metaModel.actionTypes, "humanName")
    self.cmbActionTypes = ComboBox:New {
        items = GetField(self.validActions, "humanName"),
        actionTypes = GetField(self.validActions, "name"),
        height = SCEN_EDIT.conf.B_HEIGHT,
        width = "60%",
        y = "20%",
        x = '20%',
    }
    self.cmbActionTypes.OnSelect = {
        function(object, itemIdx, selected)
            if selected and itemIdx > 0 then
                self.actionPanel:ClearChildren()
                local actName = self.cmbActionTypes.actionTypes[itemIdx]
                local action = self.validActions[itemIdx]
                for i = 1, #action.input do
                    local input = action.input[i]
                    local subPanelName = input.name
                    if input.humanName then
                        
                    end
                    local subPanel = SCEN_EDIT.createNewPanel(input.type, self.actionPanel)
                    if subPanel then
                        self.actionPanel[subPanelName] = subPanel
                        SCEN_EDIT.MakeSeparator(self.actionPanel)
                    end
                end
            end
        end
    }

    self.window =  Window:New {
        resizable = false,
        clientWidth = 300,
        clientHeight = 300,
        x = 500,
        y = 300,
        parent = screen0,
        children = {
            self.cmbActionTypes,
            self.btnOk,
            self.btnCancel,
            ScrollPanel:New {
                x = 1,
                y = self.cmbActionTypes.y + self.cmbActionTypes.height + 80,
                bottom = 1,
                right = 5,
                children = {
                    self.actionPanel,
                },
            },
        }
    }
    
    self.btnCancel.OnClick = {
        function() 
            self.triggerWindow.window.disableChildrenHitTest = false
            self.window:Dispose()
        end
    }
    
    self.btnOk.OnClick = {
        function()            
            if self.mode == 'edit' then
                self:EditAction()
                self.triggerWindow.window.disableChildrenHitTest = false
                self.window:Dispose()
            elseif self.mode == 'add' then
                self:AddAction()
                self.triggerWindow.window.disableChildrenHitTest = false
                self.window:Dispose()
            end
        end
    }
    
    self.cmbActionTypes:Select(0)
    self.cmbActionTypes:Select(1)

    local tw = self.triggerWindow.window
    local sw = self.window
    if self.mode == 'add' then
        self.window.caption = "New action for - " .. self.trigger.name
        sw.x = tw.x
        sw.y = tw.y + tw.height + 5
        if tw.parent.height <= sw.y + sw.height then
            sw.y = tw.y - sw.height
        end
    elseif self.mode == 'edit' then
        self.cmbActionTypes:Select(GetIndex(self.cmbActionTypes.actionTypes, self.action.actionTypeName))
        self:UpdatePanel()
        self.window.caption = "Edit action for trigger " .. self.trigger.name
        if tw.x + tw.width + sw.width > tw.parent.width then
            sw.x = tw.x - sw.width
        else
            sw.x = tw.x + tw.width
        end
        sw.y = tw.y
    end    
end

function ActionWindow:UpdatePanel()
    local actName = self.action.actionTypeName
    local index = GetIndex(self.cmbActionTypes.actionTypes, actName)
    local action = self.validActions[index]
    for i = 1, #action.input do
        local input = action.input[i]
        local subPanelName = input.name
        local subPanel = self.actionPanel[subPanelName]
        if subPanel then
            subPanel:UpdatePanel(self.action[subPanelName])
        end
    end
end

function ActionWindow:UpdateModel()
    local actName = self.action.actionTypeName
    local index = GetIndex(self.cmbActionTypes.actionTypes, actName)
    local action = self.validActions[index]
    for i = 1, #action.input do
        local input = action.input[i]
        local subPanelName = input.name
        local subPanel = self.actionPanel[subPanelName]
        if subPanel then
            self.action[subPanelName] = {}
            self.actionPanel[subPanelName]:UpdateModel(self.action[subPanelName])
        end
    end
end

function ActionWindow:EditAction()
    self.action.actionTypeName = self.cmbActionTypes.actionTypes[self.cmbActionTypes.selected]    
    self:UpdateModel()
    self.triggerWindow:Populate()
end

function ActionWindow:AddAction()
    self.action = { actionTypeName = self.cmbActionTypes.actionTypes[self.cmbActionTypes.selected] }
    self:UpdateModel()
    table.insert(self.trigger.actions, self.action)    
    self.triggerWindow:Populate()
end


