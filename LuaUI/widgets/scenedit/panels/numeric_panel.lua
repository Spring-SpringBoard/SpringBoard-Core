local Chili = WG.Chili
local model = SCEN_EDIT.model
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
        height = model.B_HEIGHT,
        parent = self.relTypePanel,
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
	numeric.relTypeId = self.cmbRelType.selected
end

function NumericPanel:UpdatePanel(numeric)
    self.edValue.text = tostring(numeric.value)
	self.cmbRelType:Select(numeric.relTypeId)
end
