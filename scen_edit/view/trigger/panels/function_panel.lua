SB.Include(SB_VIEW_FIELDS_DIR .. "field.lua")

FunctionField = Field:extends{}

-- FIXME: sources is ignored
function FunctionField:init(field)
    self.width = 200

    Field.init(self, field)

    self.btnFunction = Button:New {
        caption = "Function",
        width = self.width,
        height = self.height,
        OnClick = {
            function()
                local mode = 'add'
                if self.value then
                    mode = 'edit'
                end
                local functionWindow = FunctionWindow({
                    mode = mode,
                    dataType = self.dataType,
                    element = self.value,
                    trigger = self.trigger,
                    params = self.params,

                    OnConfirm = {
                        function(element)
                            self:Set(element)
                        end
                    },
                })
                --SB.MakeWindowModal(customWindow.window, self.parent.parent.parent)
                -- SB.MakeWindowModal(functionWindow.window, self.parent)
            end
        },
    }

    self.components = {
        self.btnFunction
    }
end

-- Function window class
FunctionWindow = AbstractTriggerElementWindow:extends{}

function FunctionWindow:init(opts)
    self.dataType = opts.dataType
    AbstractTriggerElementWindow.init(self, opts)
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
