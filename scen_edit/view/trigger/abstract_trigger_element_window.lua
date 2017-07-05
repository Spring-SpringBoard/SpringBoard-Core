SB.Include(Path.Join(SB_VIEW_DIR, "editor.lua"))

AbstractTriggerElementWindow = Editor:extends{}

-- abstract
function AbstractTriggerElementWindow:GetValidElementTypes()
end

-- abstract
function AbstractTriggerElementWindow:OnExprTypeChange(exprType)
end

function AbstractTriggerElementWindow:init(opts)
    Editor.init(self)

    -- Mode: either 'add' or 'edit'
    self.mode = opts.mode
    -- Element to edit
    self.element = opts.element
    -- Trigger this element belongs to
    self.trigger = opts.trigger
    -- Additional trigger parameters
    self.params = opts.params

    self.OnConfirm = opts.OnConfirm or {}

    self.btnOK = Button:New {
        caption = "OK",
        height = SB.conf.B_HEIGHT,
        width = "40%",
        x = 10,
        y = 20,
        backgroundColor = SB.conf.BTN_OK_COLOR,
    }
    self.btnCancel = Button:New {
        caption = "Cancel",
        height = SB.conf.B_HEIGHT,
        width = "40%",
        x = "55%",
        y = 20,
        backgroundColor = SB.conf.BTN_CANCEL_COLOR,
    }
    self.elementPanel = StackPanel:New {
        itemMargin = {0, 0, 0, 0},
        y = 200,
        x = 0,
        right = 0,
        bottom = 0,
        padding = {0, 0, 0, 0}
    }

    self.elementTypes = SortByName(self:GetValidElementTypes(), "humanName")
    -- group by tags
    self:_AddTagGroups()


    if not self.fields["elementType"] then
        self:AddField(ChoiceField({
            name = "elementType",
            captions = GetField(self.elementTypes, "humanName"),
            items = GetField(self.elementTypes, "name"),
        }))
    end
    self:__RefreshElementType()

    self.btnCancel.OnClick = {
        function()
            self.window:Dispose()
        end
    }

    self.btnOK.OnClick = {
        function()
            local success, subPanels = false, nil
            if self.mode == 'edit' then
                success, subPanels = self:EditElement()
            elseif self.mode == 'add' then
                success, subPanels = self:AddElement()
            end

            if success then
                CallListeners(self.OnConfirm, self.element)
                self.window:Dispose()
            else
                if subPanels ~= nil and #subPanels > 0 then
                    for _, subPanel in pairs(subPanels) do
                        SB.HintControl(subPanel)
                    end
                end
            end
        end
    }

    local children = {
        self.btnOK,
        self.btnCancel,
        self.elementPanel
    }

    table.insert(children,
        ScrollPanel:New {
            x = 0,
            y = 60,
            bottom = 30,
            right = 0,
            borderColor = {0,0,0,0},
            horizontalScrollbar = false,
            children = { self.stackPanel },
        }
    )

    self:Finalize(children, {notMainWindow = true, noCloseButton = true})

    if self.mode == 'edit' then
        local elTypeName = self.element.typeName
        local elType = self:GetValidElementTypes()[elTypeName]

        if elType then
            local elTags = elType.tags
            if elTags and self.fields["tag"] then
                local primaryTag = elTags[1]
                self:Set("tag", primaryTag)
            end

            self:Set("elementType", elTypeName)
        end
        self:UpdatePanel()
    end

    self.window.caption = self:GetWindowCaption()
end

function AbstractTriggerElementWindow:__RefreshTagGroups()
    self.elementTypes = self.tagGroups[self.fields["tag"].value]

    if self.fields["elementType"] then
        self:RemoveField("elementType")
    end

    self:AddField(ChoiceField({
        name = "elementType",
        captions = GetField(self.elementTypes, "humanName"),
        items = GetField(self.elementTypes, "name"),
    }))

    self:__RefreshElementType()
end

function AbstractTriggerElementWindow:__RefreshElementType()
    self.elementPanel:ClearChildren()
    local elType = self:GetValidElementTypes()[self.fields["elementType"].value]
    local changedExprType = self.elType ~= elType
    self.elType = elType

    if self.elType and self.elType.input then
        local params = self.params
        local extraSourcesFunction = self.elType.extraSources
        if extraSourcesFunction then
            params = SB.deepcopy(params)
            for _, es in pairs(extraSourcesFunction) do
                table.insert(params, es)
            end
        end
        for i = 1, #self.elType.input do
            local dataType = self.elType.input[i]

            local paramsI = params
            local extraSourcesInput = dataType.extraSources
            if extraSourcesInput then
                paramsI = SB.deepcopy(paramsI)
                for _, es in pairs(extraSourcesInput) do
                    table.insert(paramsI, es)
                end
            end

            local subPanelName = dataType.name
            Log.Debug("Adding subpanel: " .. tostring(dataType.type))
            local subPanel = SB.createNewPanel({
                dataType = dataType,
                parent = self.elementPanel,
                trigger = self.trigger,
                params = paramsI
            })
            if subPanel then
                self.elementPanel[subPanelName] = subPanel
                if i ~= #self.elType.input then
                    SB.MakeSeparator(self.elementPanel)
                end
            end
        end
    else
        local subPanelName = self.elType.name
        local subPanel = SB.createNewPanel({
            dataType = {
                type = self.elType.name,
                sources = "pred",
            },
            parent = self.elementPanel,
            params = self.params,
        })
        if subPanel then
            self.elementPanel[subPanelName] = subPanel
        end
    end
    if changedExprType then
        self:OnExprTypeChange(self.elType)
    end
end

function AbstractTriggerElementWindow:OnFieldChange(name, value)
    if name == "tag" then
        self:__RefreshTagGroups()
    elseif name == "elementType" then
        self:__RefreshElementType()
    end
end

function AbstractTriggerElementWindow:_AddTagGroups()
    if #self.elementTypes <= 10 then
        return
    end

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

    self:AddField(ChoiceField({
        name = "tag",
        items = GetKeys(self.tagGroups),
    }))

    self:__RefreshTagGroups()
end

function AbstractTriggerElementWindow:UpdatePanel()
    local elTypeName = self.element.typeName
    local elType = self:GetValidElementTypes()[self.fields["elementType"].value]
    if elType and elType.input then
        for _, dataType in pairs(elType.input) do
            local subPanelName = dataType.name
            local subPanel = self.elementPanel[subPanelName]
            if subPanel then
                subPanel:UpdatePanel(self.element[subPanelName])
            end
        end
    else
        local subPanelName = self.elType.name
        local subPanel = self.elementPanel[subPanelName]
        if subPanel then
            subPanel:UpdatePanel(self.element)
        end
    end
end

function AbstractTriggerElementWindow:UpdateModel()
    local elTypeName = self.element.typeName
    local elType = self:GetValidElementTypes()[self.fields["elementType"].value]

    local success = true
    local errorSubPanels = {}
    if elType and elType.input then
        for _, dataType in pairs(elType.input) do
            local subPanelName = dataType.name
            local subPanel = self.elementPanel[subPanelName]
            if subPanel then
                self.element[subPanelName] = {}
                if not self.elementPanel[subPanelName]:UpdateModel(self.element[subPanelName]) then
                    success = false
                    table.insert(errorSubPanels, subPanel.stackPanel)
                end
            end
        end
    else
        local subPanelName = self.elType.name
        local subPanel = self.elementPanel[subPanelName]
        if subPanel then
            self.element = {}
            if not self.elementPanel[subPanelName]:UpdateModel(self.element) then
                success = false
                table.insert(errorSubPanels, subPanel.stackPanel)
            end
        end
    end
    return success, errorSubPanels
end

function AbstractTriggerElementWindow:EditElement()
    local _element = SB.deepcopy(self.element)
    self.element.typeName = self.fields["elementType"].value
    local success, subPanels = self:UpdateModel()
    if not success then
        SetTableValues(self.element, _element)
        return false, subPanels
    end
    return true
end

function AbstractTriggerElementWindow:AddElement()
    self.element = {}
    self.element.typeName = self.fields["elementType"].value
    local success, subPanels = self:UpdateModel()
    if not success then
        self.element = nil
        return false, subPanels
    end
    return true
end
