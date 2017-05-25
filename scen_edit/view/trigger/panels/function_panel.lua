FunctionPanel = AbstractTypePanel:extends{}

-- FIXME: sources is ignored
function FunctionPanel:init(opts)
    opts.dataType.sources = {"pred"}
    self:super('init', opts)
end

function FunctionPanel:MakePredefinedOpt()
    local stackFunctionPanel = MakeComponentPanel(self.parent)
    self.cbPredefined = Checkbox:New {
        caption = "Predefined function: ",
        right = 100 + 10,
        x = 1,
        checked = true,
        parent = stackFunctionPanel,
    }
    table.insert(self.radioGroup, self.cbPredefined)
    self.btnFunction = Button:New {
        caption = "Function",
        right = 1,
        width = 100,
        parent = stackFunctionPanel,
        data = {},
        OnClick = {
            function()
                local mode = 'add'
                if #self.btnFunction.data > 0 then
                    mode = 'edit'
                end
                FunctionWindow({
                    parentWindow = self.parent.parent.parent,
                    mode = mode,
                    dataType = self.dataType,
                    parentObj = self.btnFunction.data,
                    condition = self.btnFunction.data[1],
                    cbExpressions = self.cbPredefined,
                    btnExpressions = self.btnFunction,
                    trigger = self.trigger,
                    params = self.params,
                })
            end
        },
    }
end

function FunctionPanel:UpdateModel(field)
    if self.cbPredefined and self.cbPredefined.checked and self.btnFunction.data ~= nil and #self.btnFunction.data ~= 0 then
        field.type = "pred"
        field.expr = self.btnFunction.data
        return true
    end
    return self:super('UpdateModel', field)
end

function FunctionPanel:UpdatePanel(field)
    if field.type == "pred" then
        if not self.cbPredefined.checked then
            self.cbPredefined:Toggle()
        end
        self.btnFunction.data = field.expr
        return true
    end
    return self:super('UpdatePanel', field)
end

-- Function window class
FunctionWindow = AbstractTriggerElementWindow:extends{}

function FunctionWindow:init(opts)
    opts.element = opts.condition
    self:super("init", opts)
end

-- TODO: Checking if input types are equivalent should be removed to a
-- meta-programming utility file.
local function isMatch(inputTypes1, inputTypes2)
    if #inputTypes1 ~= #inputTypes2 then
        return false
    end
    local isMatched2 = {} -- index mapping of inputs already used in the matching
    for _, input1 in pairs(inputTypes1) do
        local matched1 = true
        for i, inputType2 in pairs(inputTypes2) do
            if not isMatched2[i] then
                if inputType1.type == inputType2.type then
                    isMatched2[i] = true
                    matched1 = true
                    break
                end
            end
        end
        if not matched1 then
            return false
        end
    end
    return false
end

function FunctionWindow:GetValidElementTypes()
    local validFunctionTypes = {}

    local functionTypes
    if self.dataType.type == "function" then
        -- If specified, Filter based on matching output data types.
        if self.dataType.output then
            functionTypes = SB.metaModel.functionTypesByOutput[self.dataType.output]
        else
            functionTypes = SB.metaModel.functionTypes
        end
    -- FIXME: things might need cleanup for well designed action support
    elseif self.dataType.type == "action" then
        functionTypes = SB.metaModel.actionTypes
    else
        Log.Error("Unexeptected data type: " .. tostring(self.dataType.type))
    end

    -- If specified, Filter based on matching input data types.
    if self.dataType.input ~= nil then
        for _, functionType in pairs(functionTypes) do
            if isMatch(functionType.input, self.dataType.input) then
                table.insert(validFunctionTypes, functionType)
            end
        end
    else
        validFunctionTypes = functionTypes
    end

    return validFunctionTypes
end

function FunctionWindow:GetWindowCaption()
    -- FIXME: better function display if possible
    if self.mode == 'add' then
        return "New function"
    elseif self.mode == 'edit' then
        return "Edit function"
    end
end

function FunctionWindow:AddParent()
    table.insert(self.parentObj, self.element)
end
