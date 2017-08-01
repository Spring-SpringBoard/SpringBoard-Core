TypePanel = Editor:extends{}

function TypePanel:init(opts)
    Editor.init(self)

    self.stackPanel = opts.parent

    assert(opts.dataType, "dataType cannot be nil")
    assert(opts.parent, "parent cannot be nil")
    --assert(opts.trigger, "trigger cannot be nil")
    assert(opts.params, "params cannot be nil")

    self.dataType = opts.dataType
    self.sources = opts.dataType.sources or {"const", "scoped", "var", "expr"}
    self.sourceNames = {
        const = "Value",
        scoped = "Parameter",
        var = "Variable",
        expr = "Expression",
    }
    if type(self.sources) == "string" then
        self.sources = {self.sources}
    end

    self.trigger = opts.trigger
    self.params = opts.params
    self.FieldType = opts.FieldType
    self.parent = opts.parent

    self.choiceWidth = 140
    self.valueWidth = 300

    self.OnBegin = opts.OnBegin or {}
    CallListeners(self.OnBegin, self)

    self.sourceFieldMap = {}
    for _, source in pairs(self.sources) do
        if source == "const" then
            self:MakeConstOpt()
        elseif source == "scoped" then
            self:MakeScopedOpt()
        elseif source == "var" then
            self:MakeVariableOpt()
        elseif source == "expr" then
            self:MakeExpressionOpt()
        end
    end

    local names = GetKeys(self.sourceFieldMap)
    local fields = GetValues(self.sourceFieldMap)
    local captions = {}
    for _, name in pairs(names) do
        table.insert(captions, self.sourceNames[name])
    end
    if #names == 0 then
        return
    elseif #names > 1 then
        -- Offset all fields by self.choiceWidth
        for _, field in pairs(fields) do
            for _, comp in pairs(field.components) do
                if not comp.x then
                    comp.x = 0
                end
                comp.x = comp.x + self.choiceWidth + 10
            end
        end
        -- Add Choice field that controls which field gets selected
        table.insert(fields, 1,
            ChoiceField({
                x = 0,
                name = "sourceType",
                items = names,
                captions = captions,
                width = self.choiceWidth,
            })
        )

        self.groupField = GroupField(fields)
        self.groupField.autoSize = false
        self:AddField(self.groupField)
    else
        self:AddField(Field({
            name = "sourceType",
            value = names[1],
        }))
        self:AddField(fields[1])
    end

    self.__initializing = false

    self:_RefreshSourceTypes()
end

function TypePanel:_RefreshSourceTypes()
    if not self.groupField then
        return
    end

    local invisibleFields = {}
    for fname, _ in pairs(self.sourceFieldMap) do
        if fname ~= self.fields["sourceType"].value then
            table.insert(invisibleFields, fname)
        end
    end
    self.groupField:_HackSetInvisibleFields(invisibleFields)
end

-- abstract
function TypePanel:MakeConstOpt()
    local allowNil = not not self.dataType.allowNil
    -- Uses a FieldType specified in the constructor
    self.sourceFieldMap["const"] = self.FieldType({
        name = "const",
        width = self.valueWidth,
        x = self.choiceWidth,
        allowNil = allowNil,
    })
end

function TypePanel:MakeScopedOpt()
    local validParams = {}
    for _, param in pairs(self.params) do
        if param.type == self.dataType.type then
            table.insert(validParams, param)
        end
    end
    if #validParams == 0 then
        return
    end

    self.sourceFieldMap["scoped"] = ChoiceField({
        name = "scoped",
        width = self.valueWidth,
        x = self.choiceWidth,
        items = GetField(validParams, "name"),
        captions = GetField(validParams, "humanName"),
    })
end

function TypePanel:MakeVariableOpt()
    --VARIABLE
    local variablesOfType = SB.model.variableManager:getVariablesOfType(self.dataType.type)
    if not variablesOfType then
        return
    end
    local variableNames = {}
    local variableIDs = {}
    for id, variable in pairs(variablesOfType) do
        table.insert(variableNames, variable.name)
        table.insert(variableIDs, id)
    end

    if #variableIDs == 0 then
        return
    end

    self.sourceFieldMap["var"] = ChoiceField({
        name = "var",
        width = self.valueWidth,
        x = self.choiceWidth,
        captions = variableNames,
        items = variableIDs,
    })
end

function TypePanel:MakeExpressionOpt()
    --EXPRESSION
    local viableExpressions = SB.metaModel.functionTypesByOutput[self.dataType.type]
    if not viableExpressions then
        return
    end

    self.sourceFieldMap["expr"] = Field({
        name = "expr",
        width = self.valueWidth,
        x = self.choiceWidth,
        -- FIXME: it seems that similarity check doesn't always work well in field.lua
        __dontCheckIfSimilar = true,
        components = {
            Button:New {
                caption = 'Select...',
                width = self.valueWidth,
                height = 30,
                data = {},
                OnClick = {
                    function()
                        self:__MakeExpressionWindow()
                    end
                }
            }
        }
    })
end

function TypePanel:__MakeExpressionWindow()
    local mode = 'add'
    local expr = self.fields["expr"].value
    if expr then
        mode = 'edit'
    end
    local customWindow = CustomWindow({
        mode = mode,
        dataType = self.dataType,
        condition = expr,
        trigger = self.trigger,
        params = self.params,

        OnConfirm = {
            function(element)
                if mode == 'add' then
                    expr = element
                end
                self:Set("expr", expr)
            end
        }
    })
    SB.MakeWindowModal(customWindow.window, self.parent)
end

-- abstract
function TypePanel:UpdateModel(field)
    local sourceType = self.fields["sourceType"].value

    field.type = sourceType
    field.value = self.fields[sourceType].value

    return self:Validate(sourceType, field.value)
end

-- abstract
function TypePanel:UpdatePanel(field)
    self:Set("sourceType", field.type)
    local result = self:Validate(field.type, field.value)
    self:Set(field.type, field.value)
    return result
end

function TypePanel:OnFieldChange(name, value)
    if name == "sourceType" then
        self:_RefreshSourceTypes()
    elseif name == "expr" then
        local exprStr = SB.humanExpression(value, "condition")
        local buttonExpr = self.fields["expr"].components[1]
        --buttonExpr.tooltip = tooltip
        buttonExpr:SetCaption(exprStr)
        buttonExpr:Invalidate()
    end
end
