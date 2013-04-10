ConditionWindow = Window:Inherit {
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

local this = ConditionWindow 
local inherited = this.inherited

function ConditionWindow:New(obj)
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
    obj.conditionPanel = StackPanel:New {
        itemMargin = {0, 0, 0, 0},
        x = 1,
        y = 1,
        right = 1,
        autosize = true,
        resizeItems = false,
        padding = {0, 0, 0, 0}
    }
    obj.validConditionTypes = SortByName(SCEN_EDIT.metaModel.functionTypesByOutput["bool"], "humanName")
    obj.cmbConditionTypes = ComboBox:New {
        items = GetField(obj.validConditionTypes, "humanName"),
        conditionTypes = GetField(obj.validConditionTypes, "name"),
        height = SCEN_EDIT.conf.B_HEIGHT,
        width = "60%",
        y = "20%",
        x = '20%',
    }
    obj.cmbConditionTypes.OnSelect = {
        function(object, itemIdx, selected)
            if selected and itemIdx > 0 then
                obj.conditionPanel:ClearChildren()
--                local cndName = obj.cmbConditionTypes.conditionTypes[itemIdx]
                local condition = obj.validConditionTypes[itemIdx]
                for i = 1, #condition.input do
                    local input = condition.input[i]
                    local subPanelName = input.name
                    local subPanel = SCEN_EDIT.createNewPanel(input.type, obj.conditionPanel)
                    if subPanel then
                        obj.conditionPanel[subPanelName] = subPanel
                        SCEN_EDIT.MakeSeparator(obj.conditionPanel)
                    end
                end
            end
        end
    }
    
    obj.children = {
        obj.cmbConditionTypes,
        obj.btnOk,
        obj.btnCancel,
        ScrollPanel:New {
            x = 1,
            y = obj.cmbConditionTypes.y + obj.cmbConditionTypes.height + 80,
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
            obj.triggerWindow.disableChildrenHitTest = false
            obj:Dispose()
        end
    }
    
    obj.btnOk.OnClick = {
        function()            
            if obj.mode == 'edit' then
                obj:EditCondition()
                obj.triggerWindow.disableChildrenHitTest = false
                obj:Dispose()
            elseif obj.mode == 'add' then
                obj:AddCondition()
                obj.triggerWindow.disableChildrenHitTest = false
                obj:Dispose()
            end
        end
    }
    
    obj.cmbConditionTypes:Select(0)
    obj.cmbConditionTypes:Select(1)
    if obj.mode == 'add' then
        obj.caption = "New condition for - " .. obj.trigger.name
        local tw = obj.triggerWindow
        obj.x = tw.x
        obj.y = tw.y + tw.height + 5
        if tw.parent.height <= obj.y + obj.height then
            obj.y = tw.y - obj.height
        end
    elseif obj.mode == 'edit' then
        obj.cmbConditionTypes:Select(GetIndex(obj.cmbConditionTypes.conditionTypes, obj.condition.conditionTypeName))
        obj:UpdatePanel()
        obj.caption = "Edit condition for trigger " .. obj.trigger.name
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

function ConditionWindow:UpdatePanel()
    local cndName = self.condition.conditionTypeName
    local index = GetIndex(self.cmbConditionTypes.conditionTypes, cndName)
    local condition = self.validConditionTypes[index]
    for i = 1, #condition.input do
        local data = condition.input[i]
        local subPanelName = data.name
        local subPanel = self.conditionPanel[subPanelName]
        if subPanel then
            subPanel:UpdatePanel(self.condition[subPanelName])
        end
    end
end

function ConditionWindow:UpdateModel()
    local cndName = self.condition.conditionTypeName
    local index = GetIndex(self.cmbConditionTypes.conditionTypes, cndName)
    local condition = self.validConditionTypes[index]
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

function ConditionWindow:EditCondition()
    self.condition.conditionTypeName = self.cmbConditionTypes.conditionTypes[self.cmbConditionTypes.selected]    
    self:UpdateModel()
    self.triggerWindow:Populate()
end

function ConditionWindow:AddCondition()
    self.condition = { conditionTypeName = self.cmbConditionTypes.conditionTypes[self.cmbConditionTypes.selected] }
    self:UpdateModel()
    table.insert(self.trigger.conditions, self.condition)    
    self.triggerWindow:Populate()
end


