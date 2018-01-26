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
        classname = "option_button",
    }
    self.btnCancel = Button:New {
        caption = "Cancel",
        height = SB.conf.B_HEIGHT,
        width = "40%",
        x = "55%",
        y = 20,
        classname = "negative_button",
    }
    self.elementPanel = StackPanel:New {
        itemMargin = {0, 0, 0, 0},
        y = 150,
        x = 0,
        right = 0,
        bottom = 0,
        padding = {0, 0, 0, 0}
    }

    self.elementTypes = Table.SortByAttr(self:GetValidElementTypes(), "humanName")
    -- group by tags
    self:_AddTagGroups()

    if not self.fields["elementType"] then
        self:AddField(ChoiceField({
            name = "elementType",
            captions = GetField(self.elementTypes, "humanName"),
            items = GetField(self.elementTypes, "name"),
            width = 350,
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
            self:ConfirmDialog()
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
            y = 50,
            bottom = 0,
            right = 0,
            borderColor = {0,0,0,0},
            horizontalScrollbar = false,
            children = { self.stackPanel },
        }
    )

    self:Finalize(children, {
        notMainWindow = true,
        noCloseButton = true,
        x = tostring(math.random(30, 40)) .. "%",
        y = tostring(math.random(30, 40)) .. "%",
        width = 500,
        height = 350,
        classname = "trigger_window",
    })

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

function AbstractTriggerElementWindow:ConfirmDialog()
    local success, errorEditors = false, nil
    if self.mode == 'edit' then
        success, errorEditors = self:EditElement()
    elseif self.mode == 'add' then
        success, errorEditors = self:AddElement()
    end

    if success then
        -- Close the form
        CallListeners(self.OnConfirm, self.element)
        self.window:Dispose()
    else
        -- Display errors
        if errorEditors ~= nil and #errorEditors > 0 then
            for _, errorEditor in pairs(errorEditors) do
                SB.HintEditor(errorEditor)
            end
        else
            Log.Error(debug.traceback())
            Log.Error("Failed to confirm the operation but no errorEditors to show")
        end
    end
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
        width = 350,
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
                params = paramsI,
                OnBegin = {
                    function(obj)
                        local humanName = dataType.humanName
                        if not humanName then
                            humanName = dataType.name
                            humanName = String.Capitalize(humanName)
                        end
                        obj:AddControl(dataType.name .. "-sep", {
                            Label:New {
                                caption = humanName,
                            },
                            Line:New {
                                x = 150,
                            }
                        })
                    end
                },
            })
            if subPanel then
                self.elementPanel[subPanelName] = subPanel
            end
        end
    elseif self.__isCoreDataType then
        local subPanelName = self.elType.name
        local subPanel = SB.createNewPanel({
            dataType = {
                type = self.elType.name,
                sources = "const",
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

    local tagGroupNames = GetKeys(self.tagGroups)

    -- Don't use tags if there is just one tag group, no matter how many elements there are
    if #tagGroupNames == 1 then
        self.tagGroups = nil
        return
    end

    table.sort(tagGroupNames)
    self:AddField(ChoiceField({
        name = "tag",
        items = tagGroupNames,
        width = 350,
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
            local subElement = self.element[subPanelName]
            if subPanel and subElement then
                local validationSuccess = false
                local callOK = xpcall(
                    function()
                        validationSuccess = subPanel:UpdatePanel(subElement)
                    end,
                    function()
                        -- Lua/code error
                        Log.Error(debug.traceback())
                        Log.Error("Failed to :UpdatePanel for \"".. tostring(subPanelName) .. "\" panel for def: " .. tostring(elTypeName))
                    end
                )
                -- Failed to validate (data error)
                if callOK and not validationSuccess then
                    Log.Warning("Validation failed for \"".. tostring(subPanelName) .. "\" panel for def: " .. tostring(elTypeName) .. " with value:")
                    table.echo(subElement)
                end
            elseif not subPanel then
                Log.Error("Failed to create \"".. tostring(subPanelName) .. "\" panel for def: " .. tostring(elTypeName))
            elseif not subElement then
                -- FIXME: Issue warning as a UI notification. This is not necessarily a user error.
                Log.Warning("Missing field: \"" .. tostring(subPanelName) .. "\" for def: " .. tostring(elTypeName))
            end
        end
    elseif self.__isCoreDataType then
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
    local errorEditors = {}
    if elType and elType.input then
        for _, dataType in pairs(elType.input) do
            local subPanelName = dataType.name
            local subPanel = self.elementPanel[subPanelName]
            if subPanel then
                self.element[subPanelName] = {}
                if not self.elementPanel[subPanelName]:UpdateModel(self.element[subPanelName]) then
                    success = false
                    table.insert(errorEditors, subPanel)
                end
            end
        end
    -- FIXME: probably shouldn't be using self.__isCoreDataType explicitly
    elseif self.__isCoreDataType then
        local subPanelName = self.elType.name
        local subPanel = self.elementPanel[subPanelName]
        if subPanel then
            self.element = {}
            if not self.elementPanel[subPanelName]:UpdateModel(self.element) then
                success = false
                table.insert(errorEditors, subPanel)
            end
        end
    end
    return success, errorEditors
end

function AbstractTriggerElementWindow:EditElement()
    local _element = SB.deepcopy(self.element)
    self.element.typeName = self.fields["elementType"].value

    local success, errorEditors = self:UpdateModel()

    if not success then
        SetTableValues(self.element, _element)
        return false, errorEditors
    end
    return true
end

function AbstractTriggerElementWindow:AddElement()
    self.element = {}
    self.element.typeName = self.fields["elementType"].value

    local success, errorEditors = self:UpdateModel()

    if not success then
        self.element = nil
        return false, errorEditors
    end
    return true
end
