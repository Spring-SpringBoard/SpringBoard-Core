IdentityComparisonPanel = AbstractTypePanel:extends{}

function IdentityComparisonPanel:init(opts)
    opts.dataType.sources = {"pred"}
    self:super('init', opts)
end

function IdentityComparisonPanel:MakePredefinedOpt()
    local stackIdentityComparisonPanel = MakeComponentPanel(self.parent)
    self.cmbCmpType = ComboBox:New {
        right = 1,
        width = 100,
        height = SB.conf.B_HEIGHT,
        parent = stackIdentityComparisonPanel,
        items = SB.metaModel.identityComparisonTypes,
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
