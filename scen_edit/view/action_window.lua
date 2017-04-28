ActionWindow = LCS.class{}

function ActionWindow:init(trigger, triggerWindow, mode, action)
    self.trigger = trigger
    self.triggerWindow = triggerWindow
    self.mode = mode
    self.action = action

    SCEN_EDIT.SetControlEnabled(self.triggerWindow.window, false)
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
    -- group by tags
    if #self.validActions > 10 then
        self.tagGroups = {}
        for _, func in pairs(self.validActions) do
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
            width = "30%",
            y = "20%",
            x = 10,
        }
        self.cmbTagGroups.OnSelect = {
            function(object, itemIdx, selected)
                if selected and itemIdx > 0 then
                    self.validActions = self.tagGroups[self.cmbTagGroups.items[itemIdx]]
                    self.cmbActionTypes.items = GetField(self.validActions, "humanName")
                    self.cmbActionTypes.actionTypes = GetField(self.validActions, "name")
                    self.cmbActionTypes:Invalidate()
                    self.cmbActionTypes:Select(0)
                    self.cmbActionTypes:Select(1)
                end
            end
        }
    end
    local cmbActionTypesX = "20%"
    local cmbActionTypesWidth = "60%"
    if self.cmbTagGroups ~= nil then
        cmbActionTypesWidth = "50%"
        cmbActionTypesX = "45%"
    end

    self.cmbActionTypes = ComboBox:New {
        items = GetField(self.validActions, "humanName"),
        actionTypes = GetField(self.validActions, "name"),
        height = SCEN_EDIT.conf.B_HEIGHT,
        width = cmbActionTypesWidth,
        y = "20%",
        x = cmbActionTypesX,
    }
    self.cmbActionTypes.OnSelect = {
        function(object, itemIdx, selected)
            if selected and itemIdx > 0 then
                self.actionPanel:ClearChildren()
                local actName = self.cmbActionTypes.actionTypes[itemIdx]
                local actionType = self.validActions[itemIdx]
                for i = 1, #actionType.input do
                    local input = actionType.input[i]
                    local subPanelName = input.name
                    if input.humanName then

                    end
                    local subPanel = SCEN_EDIT.createNewPanel(input.type, self.actionPanel, input.sources, self.trigger)
                    if subPanel then
                        self.actionPanel[subPanelName] = subPanel
                        if i ~= #actionType.input then
                            SCEN_EDIT.MakeSeparator(self.actionPanel)
                        end
                    end
                end
            end
        end
    }

    self.window =  Window:New {
        resizable = false,
        width = 300,
        height = 400,
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
            self.cmbTagGroups,
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
            local success, subPanels = false, nil
            if self.mode == 'edit' then
                success, subPanels = self:EditAction()
            elseif self.mode == 'add' then
                success, subPanels = self:AddAction()
            end
            if success then
                SCEN_EDIT.SetControlEnabled(self.triggerWindow.window, true)
                self.window:Dispose()
            else
                if subPanels ~= nil and #subPanels > 0 then
                    for _, subPanel in pairs(subPanels) do
                        SCEN_EDIT.HintControl(subPanel)
                    end
                end
            end
        end
    }
    if self.cmbTagGroups ~= nil then
        self.cmbTagGroups:Select(0)
        self.cmbTagGroups:Select(1)
    end

    self.cmbActionTypes:Select(0)
    self.cmbActionTypes:Select(1)

    local tw = self.triggerWindow.window
    local sw = self.window
    if self.mode == 'add' then
        self.window.caption = "New action for - " .. self.trigger.name
        sw.x = tw.x
        sw.y = tw.y + tw.height + 5
        --if tw.parent.height <= sw.y + sw.height then
        --    sw.y = tw.y - sw.height
        --end
    elseif self.mode == 'edit' then
        local cndTags = SCEN_EDIT.metaModel.actionTypes[self.action.actionTypeName].tags
        if cndTags ~= nil and self.cmbTagGroups ~= nil then
            local primaryTag = cndTags[1]
            self.cmbTagGroups:Select(GetIndex(GetKeys(self.tagGroups), primaryTag))
        end
        self.cmbActionTypes:Select(GetIndex(self.cmbActionTypes.actionTypes, self.action.actionTypeName))
        self:UpdatePanel()
        self.window.caption = "Edit action for trigger " .. self.trigger.name
        --if tw.x + tw.width + sw.width > tw.parent.width then
        --    sw.x = tw.x - sw.width
        --else
            sw.x = tw.x + tw.width
        --end
        sw.y = tw.y
    end
end

function ActionWindow:UpdatePanel()
    local actName = self.action.actionTypeName
    local index = GetIndex(self.cmbActionTypes.actionTypes, actName)
    local actionType = self.validActions[index]
    for i = 1, #actionType.input do
        local input = actionType.input[i]
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
    local actionType = self.validActions[index]

    local success = true
    local errorSubPanels = {}
    for i = 1, #actionType.input do
        local input = actionType.input[i]
        local subPanelName = input.name
        local subPanel = self.actionPanel[subPanelName]
        if subPanel then
            self.action[subPanelName] = {}
            if not self.actionPanel[subPanelName]:UpdateModel(self.action[subPanelName]) then
                success = false
                table.insert(errorSubPanels, subPanel.parent)
            end
        end
    end
    return success, errorSubPanels
end

function ActionWindow:EditAction()
    local _action = SCEN_EDIT.deepcopy(self.action)
    self.action.actionTypeName = self.cmbActionTypes.actionTypes[self.cmbActionTypes.selected]
    local success, subPanels = self:UpdateModel()
    if not success then
        SetTableValues(self.action, _action)
        return false, subPanels
    end
    self.triggerWindow:Populate()
    return true
end

function ActionWindow:AddAction()
    self.action = { actionTypeName = self.cmbActionTypes.actionTypes[self.cmbActionTypes.selected] }
    local success, subPanels = self:UpdateModel()
    if not success then
        self.action = nil
        return false, subPanels
    end
    table.insert(self.trigger.actions, self.action)
    self.triggerWindow:Populate()
    return true
end
