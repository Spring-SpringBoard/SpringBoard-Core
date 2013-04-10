NumericComparisonPanel = {
}

function NumericComparisonPanel:New(obj)
    obj = obj or {}
    setmetatable(obj, self)
    self.__index = self
    obj:Initialize()
    return obj
end

function NumericComparisonPanel:Initialize()
    local stackNumericComparisonPanel = MakeComponentPanel(self.parent)
    self.cmbCmpType = ComboBox:New {
        right = 1,
        width = 100,
        height = SCEN_EDIT.conf.B_HEIGHT,
        parent = stackNumericComparisonPanel,
        items = SCEN_EDIT.metaModel.numericComparisonTypes,
    }
end

function NumericComparisonPanel:UpdateModel(comparison)
    comparison.cmpTypeId = self.cmbCmpType.selected
end

function NumericComparisonPanel:UpdatePanel(comparison)
    self.cmbCmpType:Select(comparison.cmpTypeId)
end
