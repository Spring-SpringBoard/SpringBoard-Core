NumericComparisonPanel = AbstractTypePanel:extends{}

function NumericComparisonPanel:init(opts)
    opts.dataType.sources = {"pred"}
    self:super('init', opts)
end

function NumericComparisonPanel:MakePredefinedOpt(parent)
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
    return true
end

function NumericComparisonPanel:UpdatePanel(comparison)
    self.cmbCmpType:Select(comparison.cmpTypeId)
    return true
end
