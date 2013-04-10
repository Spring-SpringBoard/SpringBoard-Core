local model = SCEN_EDIT.model

CustomWindow = Window:Inherit {
    classname = "window",    
    resizable = false,
    clientWidth = 300,
    clientHeight = 300,
    x = 500,
    y = 300,
    parentWindow = nil, --required
    mode = nil, --'add' or 'edit'
    dataType = nil,
}

local this = CustomWindow 
local inherited = this.inherited

function CustomWindow:New(obj)
    obj.parentWindow.disableChildrenHitTest = true    
    obj.btnOk = Button:New {
        caption = "OK",
        height = model.B_HEIGHT,
        width = "40%",
        x = "5%",
        y = "7%",
    }
    obj.btnCancel = Button:New {
        caption = "Cancel",
        height = model.B_HEIGHT,
        width = "40%",
        x = "55%",
        y = "7%",
    }    
    obj.conditionPanel = StackPanel:New {
        itemMargin = {0, 0, 0, 0},
        x = 1,
        y = 1,
        right = 1,
        autosize = true,
        resizeItems = false,
        padding = {0, 0, 0, 0}
    }
    obj.customTypes = SortByName(model.conditionTypesByOutput[obj.dataType], "humanName")
    obj.cmbCustomTypes = ComboBox:New {
        items = GetField(obj.customTypes, "humanName"),
        conditionTypes = GetField(obj.customTypes, "name"),
        height = model.B_HEIGHT,
        width = "60%",
        y = "20%",
        x = '20%',
    }
    obj.cmbCustomTypes.OnSelect = {
        function(object, itemIdx, selected)
            if selected and itemIdx > 0 then
                obj.conditionPanel:ClearChildren()
--                local cndName = obj.cmbCustomTypes.conditionTypes[itemIdx]
                local condition = obj.customTypes[itemIdx]
                for i = 1, #condition.input do
                    local data = condition.input[i]                    
                    local subPanelName = data.name
                    local subPanel = SCEN_EDIT.createNewPanel(data.type, obj.conditionPanel)
                    if subPanel then
                        obj.conditionPanel[subPanelName] = subPanel
                        SCEN_EDIT.MakeSeparator(obj.conditionPanel)
                    end
                end
            end
        end
    }
    obj.children = {
        obj.cmbCustomTypes,
        obj.btnOk,
        obj.btnCancel,
        ScrollPanel:New {
            x = 1,
            y = obj.cmbCustomTypes.y + obj.cmbCustomTypes.height + 80,
            bottom = 1,
            right = 5,
            children = {
                obj.conditionPanel,
            },
        },
    }    
    obj = inherited.New(self, obj)
    obj.btnCancel.OnClick = {
        function() 
            obj.parentWindow.disableChildrenHitTest = false
            obj:Dispose()
        end
    }
    
    obj.btnOk.OnClick = {
        function()            
            if obj.mode == 'edit' then
                obj:EditCondition()
                obj.parentWindow.disableChildrenHitTest = false
                obj:Dispose()
            elseif obj.mode == 'add' then
                obj:AddCondition()
                obj.parentWindow.disableChildrenHitTest = false
                obj:Dispose()
            end
        end
    }    
    obj.cmbCustomTypes:Select(0)
    obj.cmbCustomTypes:Select(1)

    if obj.mode == 'add' then
        obj.caption = "New expression of type " .. obj.dataType
        local tw = obj.parentWindow
        obj.x = tw.x
        obj.y = tw.y + tw.height + 5
        if tw.parent.height <= obj.y + obj.height then
            obj.y = tw.y - obj.height
        end
    elseif obj.mode == 'edit' then
        obj.cmbCustomTypes:Select(GetIndex(obj.cmbCustomTypes.conditionTypes, obj.condition.conditionTypeName))
        obj:UpdatePanel()
        obj.caption = "Edit expression of type " .. obj.dataType
        local tw = obj.parentWindow
        if tw.x + tw.width + obj.width > tw.parent.width then
            obj.x = tw.x - obj.width
        else
            obj.x = tw.x + tw.width
        end
        obj.y = tw.y
    end    

    return obj
end

function CustomWindow:UpdatePanel()
    local cndName = self.condition.conditionTypeName
    local index = GetIndex(self.cmbCustomTypes.conditionTypes, cndName)
    local condition = self.customTypes[index]
    for i = 1, #condition.input do
        local data = condition.input[i]
        local subPanelName = data.name
        local subPanel = self.conditionPanel[subPanelName]
        if subPanel then
            subPanel:UpdatePanel(self.condition[subPanelName])
        end
    end
end

function CustomWindow:UpdateModel()
    local cndName = self.condition.conditionTypeName
    local index = GetIndex(self.cmbCustomTypes.conditionTypes, cndName)
    local condition = self.customTypes[index]
    for i = 1, #condition.input do
        local data = condition.input[i]
        local subPanelName = data.name
        local subPanel = self.conditionPanel[subPanelName]
        if subPanel then
            self.condition[subPanelName] = {}
            self.conditionPanel[subPanelName]:UpdateModel(self.condition[subPanelName])
        end
    end

end

function CustomWindow:EditCondition()
    self.condition.conditionTypeName = self.cmbCustomTypes.conditionTypes[self.cmbCustomTypes.selected]    
    self:UpdateModel()
    if self.cbExpressions and not self.cbExpressions.checked then
        self.cbExpressions:Toggle()
    end    
end

function CustomWindow:AddCondition()
    self.condition = { conditionTypeName = self.cmbCustomTypes.conditionTypes[self.cmbCustomTypes.selected] }
    self:UpdateModel()
    table.insert(self.parentObj, self.condition)    
    if self.cbExpressions and not self.cbExpressions.checked then
        self.cbExpressions:Toggle()
    end
end


