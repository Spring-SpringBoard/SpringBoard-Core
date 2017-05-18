AbstractTriggerElementWindow = LCS.class.abstract{}

-- abstract
function AbstractTriggerElementWindow:GetValidElementTypes()
end

function AbstractTriggerElementWindow:init(opts)
    self.mode = opts.mode
    self.parentWindow = opts.parentWindow
    while self.parentWindow.classname ~= "window" do
        self.parentWindow = self.parentWindow.parent
    end
    self.dataType = opts.dataType
    self.parentObj = opts.parentObj
    self.element = opts.element
    self.cbExpressions = opts.cbExpressions
    self.btnExpressions = opts.btnExpressions
    self.trigger = opts.trigger
    self.triggerWindow = opts.triggerWindow

    SCEN_EDIT.SetControlEnabled(self.parentWindow, false)
    self.btnOk = Button:New {
        caption = "OK",
        height = SCEN_EDIT.conf.B_HEIGHT,
        width = "40%",
        x = 10,
        y = 20,
        backgroundColor = SCEN_EDIT.conf.BTN_OK_COLOR,
    }
    self.btnCancel = Button:New {
        caption = "Cancel",
        height = SCEN_EDIT.conf.B_HEIGHT,
        width = "40%",
        x = "55%",
        y = 20,
        backgroundColor = SCEN_EDIT.conf.BTN_CANCEL_COLOR,
    }
    self.elementPanel = StackPanel:New {
        itemMargin = {0, 0, 0, 0},
        x = 1,
        y = 1,
        right = 1,
        autosize = true,
        resizeItems = false,
        padding = {0, 0, 0, 0}
    }

    self.elementTypes = SortByName(self:GetValidElementTypes(), "humanName")
    -- group by tags
    if #self.elementTypes > 10 then
        self.tagGroups = {}
        for _, func in pairs(self.elementTypes) do
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
            y = self.btnOk.y + self.btnOk.height + 10,
            x = 10,
        }
        self.cmbTagGroups.OnSelect = {
            function(object, itemIdx, selected)
                if selected and itemIdx > 0 then
                    self.elementTypes = self.tagGroups[self.cmbTagGroups.items[itemIdx]]
                    self.cmbElementTypes.items = GetField(self.elementTypes, "humanName")
                    self.cmbElementTypes.elementTypes = GetField(self.elementTypes, "name")
                    self.cmbElementTypes:Invalidate()
                    self.cmbElementTypes:Select(0)
                    self.cmbElementTypes:Select(1)
                end
            end
        }
    end

    local cmbElementTypesX = "20%"
    local cmbElementTypesWidth = "60%"
    if self.cmbTagGroups ~= nil then
        cmbElementTypesWidth = "40%"
        cmbElementTypesX = "55%"
    end
    self.cmbElementTypes = ComboBox:New {
        items = GetField(self.elementTypes, "humanName"),
        elementTypes = GetField(self.elementTypes, "name"),
        height = SCEN_EDIT.conf.B_HEIGHT,
        width = cmbElementTypesWidth,
        y = self.btnOk.y + self.btnOk.height + 10,
        x = cmbElementTypesX,
    }

    self.cmbElementTypes.OnSelect = {
        function(object, itemIdx, selected)
            if selected and itemIdx > 0 then
                self.elementPanel:ClearChildren()
--                local cndName = self.cmbCustomTypes.conditionTypes[itemIdx]
                local exprType = self.elementTypes[itemIdx]
                if exprType.input then
                    for i = 1, #exprType.input do
                        local dataType = exprType.input[i]
                        local subPanelName = dataType.name
                        local subPanel = SCEN_EDIT.createNewPanel(dataType.type, self.elementPanel, dataType.sources, self.trigger)
                        if subPanel then
                            self.elementPanel[subPanelName] = subPanel
                            if i ~= #exprType.input then
                                SCEN_EDIT.MakeSeparator(self.elementPanel)
                            end
                        end
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
            self.cmbElementTypes,
            self.btnOk,
            self.btnCancel,
            ScrollPanel:New {
                x = 1,
                y = self.cmbElementTypes.y + self.cmbElementTypes.height + 10,
                bottom = 1,
                right = 5,
                children = {
                    self.elementPanel,
                },
            },
            self.cmbTagGroups
        }
    }

    self.btnCancel.OnClick = {
        function()
            SCEN_EDIT.SetControlEnabled(self.parentWindow, true)
            self.window:Dispose()
        end
    }

    self.btnOk.OnClick = {
        function()
            local success, subPanels = false, nil
            if self.mode == 'edit' then
                success, subPanels = self:EditElement()
            elseif self.mode == 'add' then
                success, subPanels = self:AddElement()
            end
            if success then
                if self.btnExpressions then
                    self.btnExpressions.tooltip = SCEN_EDIT.humanExpression(self.btnExpressions.data[1], "condition")
                end
                SCEN_EDIT.SetControlEnabled(self.parentWindow, true)
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

    self.cmbElementTypes:Select(0)
    self.cmbElementTypes:Select(1)

    local sw = self.window
    local tw = self.parentWindow
    if self.mode == 'add' then
        sw.caption = self:GetWindowCaption()
        sw.x = tw.x
        sw.y = tw.y + tw.height + 5
        if tw.parent.height <= sw.y + sw.height then
--            if tw.x + tw.width + sw.width > tw.parent.width then
--                sw.x = tw.x - sw.width
--            else
                sw.x = tw.x + tw.width
--            end
            sw.y = tw.y
        end
    elseif self.mode == 'edit' then
        local elTypeName = self.element.typeName
        local elType = self:GetValidElementTypes()[elTypeName]

        if elType then
            local elTags = elType.tags
            if elTags ~= nil and self.cmbTagGroups ~= nil then
                local primaryTag = elTags[1]
                self.cmbTagGroups:Select(GetIndex(GetKeys(self.tagGroups), primaryTag))
            end

            self.cmbElementTypes:Select(GetIndex(self.cmbElementTypes.elementTypes, elTypeName))

            self:UpdatePanel()
            self.window.caption = self:GetWindowCaption()
        end
--        if tw.x + tw.width + sw.width > tw.parent.width then
--            sw.x = tw.x - sw.width
--        else
            sw.x = tw.x + tw.width
--        end
        sw.y = tw.y
    end
end

function AbstractTriggerElementWindow:UpdatePanel()
    local elTypeName = self.element.typeName
    local index = GetIndex(self.cmbElementTypes.elementTypes, elTypeName)
    local elType = self.elementTypes[index]
    if elType.input then
        for _, dataType in pairs(elType.input) do
            local subPanelName = dataType.name
            local subPanel = self.elementPanel[subPanelName]
            if subPanel then
                subPanel:UpdatePanel(self.element[subPanelName])
            end
        end
    end
end

function AbstractTriggerElementWindow:UpdateModel()
    local elTypeName = self.element.typeName
    local index = GetIndex(self.cmbElementTypes.elementTypes, elTypeName)
    local elType = self.elementTypes[index]

    local success = true
    local errorSubPanels = {}
    if elType.input then
        for _, dataType in pairs(elType.input) do
            local subPanelName = dataType.name
            local subPanel = self.elementPanel[subPanelName]
            if subPanel then
                self.element[subPanelName] = {}
                if not self.elementPanel[subPanelName]:UpdateModel(self.element[subPanelName]) then
                    success = false
                    table.insert(errorSubPanels, subPanel.parent)
                end
            end
        end
    end
    return success, errorSubPanels
end

function AbstractTriggerElementWindow:EditElement()
    local _element = SCEN_EDIT.deepcopy(self.element)
    self.element.typeName = self.cmbElementTypes.elementTypes[self.cmbElementTypes.selected]
    local success, subPanels = self:UpdateModel()
    if not success then
        SetTableValues(self.element, _element)
        return false, subPanels
    end
    if self.cbExpressions and not self.cbExpressions.checked then
        self.cbExpressions:Toggle()
    end
    if self.triggerWindow then
        self.triggerWindow:Populate()
    end
    return true
end

function AbstractTriggerElementWindow:AddElement()
    self.element = {}
    self.element.typeName = self.cmbElementTypes.elementTypes[self.cmbElementTypes.selected]
    local success, subPanels = self:UpdateModel()
    if not success then
        self.element = nil
        return false, subPanels
    end
    self:AddParent()
    if self.cbExpressions and not self.cbExpressions.checked then
        self.cbExpressions:Toggle()
    end
    if self.triggerWindow then
        self.triggerWindow:Populate()
    end
    return true
end
