ConditionWindow = LCS.class{}

function ConditionWindow:init(trigger, triggerWindow, mode, condition)
    self.trigger = trigger
    self.triggerWindow = triggerWindow
    self.mode = mode
    self.condition = condition

    self.triggerWindow.window.disableChildrenHitTest = true    
    self.triggerWindow.window:Invalidate()
    self.btnOk = Button:New {
        caption = "OK",
        height = SCEN_EDIT.conf.B_HEIGHT,
        width = "40%",
        x = "5%",
        y = "7%",
        backgroundColor = SCEN_EDIT.conf.BTN_OK_COLOR,
    }
    self.btnCancel = Button:New {
        caption = "Cancel",
        height = SCEN_EDIT.conf.B_HEIGHT,
        width = "40%",
        x = "55%",
        y = "7%",
        backgroundColor = SCEN_EDIT.conf.BTN_CANCEL_COLOR,
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
    self.validConditionTypes = SortByName(SCEN_EDIT.metaModel.functionTypesByOutput["bool"], "humanName")
    -- group by tags
    if #self.validConditionTypes > 10 then
        self.tagGroups = {}
        for _, func in pairs(self.validConditionTypes) do
            if func.tags ~= nil then
                for _, tag in pairs(func.tags) do
                    if self.tagGroups[tag] == nil then
                        self.tagGroups[tag] = {}
                    end
                    table.insert(self.tagGroups[tag], func)
                end
            else
                if self.tagGroups["Other"] == nil then
                    self.tagGroups["Other"] = {}
                end
                table.insert(self.tagGroups["Other"], func)
            end
        end
        self.cmbTagGroups = ComboBox:New {
            items = GetKeys(self.tagGroups),
            height = SCEN_EDIT.conf.B_HEIGHT,
            width = "40%",
            y = "20%",
            x = 10,
        }
        self.cmbTagGroups.OnSelect = {
            function(object, itemIdx, selected)
                if selected and itemIdx > 0 then
                    self.validConditionTypes = self.tagGroups[self.cmbTagGroups.items[itemIdx]]
                    self.cmbConditionTypes.items = GetField(self.validConditionTypes, "humanName")
                    self.cmbConditionTypes.conditionTypes = GetField(self.validConditionTypes, "name")
                    self.cmbConditionTypes:Invalidate()
                    self.cmbConditionTypes:Select(0)
                    self.cmbConditionTypes:Select(1)
                end
            end
        }
    end

    local cmbConditionTypesX = "20%"
    local cmbConditionTypesWidth = "60%"
    if self.cmbTagGroups ~= nil then
        cmbConditionTypesWidth = "40%"
        cmbConditionTypesX = "55%"
    end
    self.cmbConditionTypes = ComboBox:New {
        items = GetField(self.validConditionTypes, "humanName"),
        conditionTypes = GetField(self.validConditionTypes, "name"),
        height = SCEN_EDIT.conf.B_HEIGHT,
        width = cmbConditionTypesWidth,
        y = "20%",
        x = cmbConditionTypesX,
    }

    self.cmbConditionTypes.OnSelect = {
        function(object, itemIdx, selected)
            if selected and itemIdx > 0 then
                self.conditionPanel:ClearChildren()
--                local cndName = obj.cmbConditionTypes.conditionTypes[itemIdx]
                local conditionType = self.validConditionTypes[itemIdx]
                for i = 1, #conditionType.input do
                    local input = conditionType.input[i]
                    local subPanelName = input.name
                    local subPanel = SCEN_EDIT.createNewPanel(input.type, self.conditionPanel, input.sources)
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
        clientWidth = 300,
        clientHeight = 300,
        x = 500,
        y = 300,
        trigger = nil, --required
        triggerWindow = nil, --required
        mode = nil, --'add' or 'edit'
        parent = screen0,
        children = {
            self.cmbConditionTypes,
            self.btnOk,
            self.btnCancel,
            ScrollPanel:New {
                x = 1,
                y = self.cmbConditionTypes.y + self.cmbConditionTypes.height + 80,
                bottom = 1,
                right = 5,
                children = {
                    self.conditionPanel,
                },
            },
            self.cmbTagGroups,
        }
    }
    
    self.btnCancel.OnClick = {
        function() 
            self.triggerWindow.window.disableChildrenHitTest = false
            self.triggerWindow.window:Invalidate()
            self.window:Dispose()
        end
    }
    
    self.btnOk.OnClick = {
        function()            
            if self.mode == 'edit' then
                self:EditCondition()
                self.triggerWindow.window.disableChildrenHitTest = false
                self.triggerWindow.window:Invalidate()
                self.window:Dispose()
            elseif self.mode == 'add' then
                self:AddCondition()
                self.triggerWindow.window.disableChildrenHitTest = false
                self.triggerWindow.window:Invalidate()
                self.window:Dispose()
            end
        end
    }

    if self.cmbTagGroups ~= nil then
        self.cmbTagGroups:Select(0)
        self.cmbTagGroups:Select(1)
    end
    
    self.cmbConditionTypes:Select(0)
    self.cmbConditionTypes:Select(1)

    local tw = self.triggerWindow.window
    local sw = self.window
    if self.mode == 'add' then
        sw.caption = "New condition for - " .. self.trigger.name
        sw.x = tw.x
        sw.y = tw.y + tw.height + 5
        --if tw.parent.height <= sw.y + sw.height then
        --    sw.y = tw.y - sw.height
        --end
    elseif self.mode == 'edit' then
        local cndTags = SCEN_EDIT.metaModel.functionTypesByOutput["bool"][self.condition.conditionTypeName].tags
        if cndTags ~= nil and self.cmbTagGroups ~= nil then
            local primaryTag = cndTags[1]
            self.cmbTagGroups:Select(GetIndex(GetKeys(self.tagGroups), primaryTag))
        end
        self.cmbConditionTypes:Select(GetIndex(self.cmbConditionTypes.conditionTypes, self.condition.conditionTypeName))
        self:UpdatePanel()
        sw.caption = "Edit condition for trigger " .. self.trigger.name
        --if tw.x + tw.width + sw.width > tw.parent.width then
        --    sw.x = tw.x - sw.width
        --else
            sw.x = tw.x + tw.width
        --end
        sw.y = tw.y
    end    
end

function ConditionWindow:UpdatePanel()
    local cndName = self.condition.conditionTypeName
    local index = GetIndex(self.cmbConditionTypes.conditionTypes, cndName)
    local conditionType = self.validConditionTypes[index]
    for i = 1, #conditionType.input do
        local data = conditionType.input[i]
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
    local conditionType = self.validConditionTypes[index]
    for i = 1, #conditionType.input do
        local data = conditionType.input[i]
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
