IdentityComparisonPanel = AbstractTypePanel:extends{}

function IdentityComparisonPanel:init(parent, ...)
    self:super('init', 'identity_comparison', parent, "pred", ...)
end

function IdentityComparisonPanel:MakePredefinedOpt()
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
    return true
end

function IdentityComparisonPanel:UpdatePanel(comparison)
    self.cmbCmpType:Select(comparison.cmpTypeId)
    return true
end
