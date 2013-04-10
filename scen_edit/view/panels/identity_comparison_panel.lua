IdentityComparisonPanel = {
}

function IdentityComparisonPanel:New(obj)
    obj = obj or {}
    setmetatable(obj, self)
    self.__index = self
    obj:Initialize()
    return obj
end

function IdentityComparisonPanel:Initialize()
    local stackIdentityComparisonPanel = MakeComponentPanel(self.parent)
    self.cmbCmpType = ComboBox:New {
        right = 1,
        width = 100,
        height = SCEN_EDIT.conf.B_HEIGHT,
        parent = stackIdentityComparisonPanel,
        items = SCEN_EDIT.metaModel.identityComparisonTypes,
    }
end

function IdentityComparisonPanel:UpdateModel(comparison)
    comparison.cmpTypeId = self.cmbCmpType.selected
end

function IdentityComparisonPanel:UpdatePanel(comparison)
    self.cmbCmpType:Select(comparison.cmpTypeId)
end
