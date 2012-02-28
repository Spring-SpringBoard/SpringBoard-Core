local Chili
Chili = WG.Chili
local C_HEIGHT = 16
local B_HEIGHT = 26
local numericRelTypes = {"==", "~=", "<=", ">=", ">", "<"} -- maybe use more user friendly signs

NumericPanel = {
}

function NumericPanel:New(obj)
    obj = obj or {}
    setmetatable(obj, self)
    self.__index = self
    obj:Initialize()
    return obj
end

function NumericPanel:Initialize()
    self.cmbRelType = ComboBox:New {
        right = 1,
        width = 100,
        height = B_HEIGHT,
        parent = relTypePanel,
        items = numericRelTypes,
    }
    local stackValuePanel = MakeComponentPanel(self.parent)
    local lblValue = Chili.Label:New {
        caption = "Value:",
        right = 100 + 10,
        x = 1,
        parent = stackValuePanel,
    }
    self.edValue = Chili.EditBox:New {
        text = "0",
        right = 1,
        width = 100,
        parent = stackValuePanel,
    }
end

function NumericPanel:UpdateModel(numeric)
    numeric.value = tonumber(self.edValue.text) or 0
--    numeric.relation = self.
end

function NumericPanel:UpdatePanel(numeric)
    self.edValue.text = tostring(numeric.value)
end
