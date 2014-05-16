CustomWindow = LCS.class{}

function CustomWindow:init(parentWindow, mode, dataType, parentObj, condition, cbExpressions)
    self.mode = mode
    self.parentWindow = parentWindow
    self.dataType = dataType
    self.parentObj = parentObj
    self.condition = condition
    self.cbExpressions = cbExpressions

    self.btnOk = Button:New {
        caption = "OK",
        height = SCEN_EDIT.conf.B_HEIGHT,
        width = "40%",
        x = 10,
        y = 20,
    }
    self.btnCancel = Button:New {
        caption = "Cancel",
        height = SCEN_EDIT.conf.B_HEIGHT,
        width = "40%",
        x = "55%",
        y = 20,
    }    
    self.conditionPanel = StackPanel:New {
        itemMargin = {0, 0, 0, 0},
        x = 1,
        y = 1,
        right = 1,
        autosize = true,
        resizeItems = false,
        padding = {0, 0, 0, 0}
    }
    self.customTypes = SortByName(SCEN_EDIT.metaModel.functionTypesByOutput[self.dataType], "humanName")
    self.cmbCustomTypes = ComboBox:New {
        items = GetField(self.customTypes, "humanName"),
        conditionTypes = GetField(self.customTypes, "name"),
        height = SCEN_EDIT.conf.B_HEIGHT,
        width = "60%",
        y = self.btnOk.y + self.btnOk.height + 10,
        x = (self.btnOk.x + self.btnCancel.x) / 2,
    }
    self.cmbCustomTypes.OnSelect = {
        function(object, itemIdx, selected)
            if selected and itemIdx > 0 then
                self.conditionPanel:ClearChildren()
--                local cndName = self.cmbCustomTypes.conditionTypes[itemIdx]
                local condition = self.customTypes[itemIdx]
                for i = 1, #condition.input do
                    local data = condition.input[i]                    
                    local subPanelName = data.name
                    local subPanel = SCEN_EDIT.createNewPanel(data.type, self.conditionPanel)
                    if subPanel then
                        self.conditionPanel[subPanelName] = subPanel
                        SCEN_EDIT.MakeSeparator(self.conditionPanel)
                    end
                end
            end
        end
    }
    self.window = Window:New {
        resizable = false,
        width = 350,
        height = 400,
        x = 500,
        y = 300,
        parent = screen0,
        children = {
            self.cmbCustomTypes,
            self.btnOk,
            self.btnCancel,
            ScrollPanel:New {
                x = 1,
                y = self.cmbCustomTypes.y + self.cmbCustomTypes.height + 80,
                bottom = 1,
                right = 5,
                children = {
                    self.conditionPanel,
                },
            },
        }
    }

    self.parentWindow.disableChildrenHitTest = true    
    self.parentWindow:Invalidate()

    self.btnCancel.OnClick = {
        function() 
            self.parentWindow.disableChildrenHitTest = false
            self.parentWindow:Invalidate()
            self.window:Dispose()
        end
    }
    
    self.btnOk.OnClick = {
        function()            
            if self.mode == 'edit' then
                self:EditCondition()
                self.parentWindow.disableChildrenHitTest = false
                self.parentWindow:Invalidate()
                self.window:Dispose()
            elseif self.mode == 'add' then
                self:AddCondition()
                self.parentWindow.disableChildrenHitTest = false
                self.parentWindow:Invalidate()
                self.window:Dispose()
            end
        end
    }    
    self.cmbCustomTypes:Select(0)
    self.cmbCustomTypes:Select(1)

    local tw = self.parentWindow
    local sw = self.window
    if self.mode == 'add' then
        self.window.caption = "New expression of type " .. self.dataType
        sw.x = tw.x
        sw.y = tw.y + tw.height + 5
        if tw.parent.height <= sw.y + sw.height then
            sw.y = tw.y - sw.height
        end
    elseif self.mode == 'edit' then
        self.cmbCustomTypes:Select(GetIndex(self.cmbCustomTypes.conditionTypes, self.condition.conditionTypeName))
        self:UpdatePanel()
        self.window.caption = "Edit expression of type " .. self.dataType
        if tw.x + tw.width + sw.width > screen0.width then
            sw.x = tw.x - sw.width
        else
            sw.x = tw.x + tw.width
        end
        sw.y = tw.y
    end    
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


