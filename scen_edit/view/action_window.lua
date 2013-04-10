ActionWindow = Window:Inherit {
    classname = "window",    
    resizable = false,
    clientWidth = 300,
    clientHeight = 300,
    x = 500,
    y = 300,
    trigger = nil, --required
    triggerWindow = nil, --required
    mode = nil, --'add' or 'edit'
}

local this = ActionWindow 
local inherited = this.inherited

function ActionWindow:New(obj)
    obj.triggerWindow.disableChildrenHitTest = true    
    obj.btnOk = Button:New {
        caption = "OK",
        height = SCEN_EDIT.conf.B_HEIGHT,
        width = "40%",
        x = "5%",
        y = "7%",
    }
    obj.btnCancel = Button:New {
        caption = "Cancel",
        height = SCEN_EDIT.conf.B_HEIGHT,
        width = "40%",
        x = "55%",
        y = "7%",
    }    
    obj.actionPanel = StackPanel:New {
        itemMargin = {0, 0, 0, 0},
        x = 1,
        y = 1,
        right = 1,
        autosize = true,
        resizeItems = false,
        padding = {0, 0, 0, 0}
    }
    obj.validActions = SortByName(SCEN_EDIT.metaModel.actionTypes, "humanName")
    obj.cmbActionTypes = ComboBox:New {
        items = GetField(obj.validActions, "humanName"),
        actionTypes = GetField(obj.validActions, "name"),
        height = SCEN_EDIT.conf.B_HEIGHT,
        width = "60%",
        y = "20%",
        x = '20%',
    }
    obj.cmbActionTypes.OnSelect = {
        function(object, itemIdx, selected)
            if selected and itemIdx > 0 then
                obj.actionPanel:ClearChildren()
                local actName = obj.cmbActionTypes.actionTypes[itemIdx]
                local action = obj.validActions[itemIdx]
                for i = 1, #action.input do
                    local input = action.input[i]
                    local subPanelName = input.name
                    if input.humanName then
                        
                    end
                    local subPanel = SCEN_EDIT.createNewPanel(input.type, obj.actionPanel)
                    if subPanel then
                        obj.actionPanel[subPanelName] = subPanel
                        SCEN_EDIT.MakeSeparator(obj.actionPanel)
                    end
                end
            end
        end
    }

    obj.children = {
        obj.cmbActionTypes,
        obj.btnOk,
        obj.btnCancel,
        ScrollPanel:New {
            x = 1,
            y = obj.cmbActionTypes.y + obj.cmbActionTypes.height + 80,
            bottom = 1,
            right = 5,
            children = {
                obj.actionPanel,
            },
        },
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
                obj:EditAction()
                obj.triggerWindow.disableChildrenHitTest = false
                obj:Dispose()
            elseif obj.mode == 'add' then
                obj:AddAction()
                obj.triggerWindow.disableChildrenHitTest = false
                obj:Dispose()
            end
        end
    }
    
    obj.cmbActionTypes:Select(0)
    obj.cmbActionTypes:Select(1)
    if obj.mode == 'add' then
        obj.caption = "New action for - " .. obj.trigger.name
        local tw = obj.triggerWindow
        obj.x = tw.x
        obj.y = tw.y + tw.height + 5
        if tw.parent.height <= obj.y + obj.height then
            obj.y = tw.y - obj.height
        end
    elseif obj.mode == 'edit' then
        obj.cmbActionTypes:Select(GetIndex(obj.cmbActionTypes.actionTypes, obj.action.actionTypeName))
        obj:UpdatePanel()
        obj.caption = "Edit action for trigger " .. obj.trigger.name
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


