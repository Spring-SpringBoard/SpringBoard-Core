local Chili = WG.Chili
local model = SCEN_EDIT.model

local unitAttrTypes = {"HP", "HP%", "Type", "Team"}
local setRelTypes = {"is", "is not"}
UnitAttrPanel = {
}

function UnitAttrPanel:New(obj)
    obj = obj or {}
    setmetatable(obj, self)
    self.__index = self
    obj:Initialize()
    return obj
end

function UnitAttrPanel:Initialize()
    local stackAttrPanel = MakeComponentPanel(self.parent)
    local lblAttrType = Chili.Label:New {
        caption = "Attribute type:",
        right = 100 + 10,
        x = 1,
        parent = stackAttrPanel,
    }

    self.cmbAttrType = ComboBox:New {
        right = 1,
        width = 100,
        height = model.B_HEIGHT,
        parent = stackAttrPanel,
        items = unitAttrTypes,
        selected = 0,
    }
    self.stackAttrOptions = Chili.StackPanel:New {
        itemMargin = {0, 0, 0, 0},
        x = 1,
        y = 1,
        right = 1,
        autosize = true,
        resizeItems = false,
        padding = {0, 0, 0, 0},
        parent = self.parent,
    }
    self.cmbAttrType.OnSelectItem = {
        function(obj, itemIdx, selected)
            if selected and itemIdx > 0 then
                self.stackAttrOptions:ClearChildren()
                local attrTypeId = itemIdx
                local numeric = false
                local set = false
                local teamAttr = false
                local typeAttr = false

                if attrTypeId == 1 or attrTypeId == 2 then
                    numeric = true
                end
                if attrTypeId == 3 or attrTypeId == 4 then
                    set = true
                end

                if attrTypeId == 3 then
                    typeAttr = true
                end

                if attrTypeId == 4 then
                    teamAttr = true
                end

                local relTypePanel = MakeComponentPanel(self.stackAttrOptions)
                local lblRelType = Chili.Label:New {
                    caption = "Relation:",
                    right = 100 + 10,
                    x = 1,
                    parent = relTypePanel,
                }

                if numeric then
                    self.stackAttrOptions.numericPanel = NumericPanel:New {
                        parent = self.stackAttrOptions,
						relTypePanel = relTypePanel,
                    }
                elseif set then
                    local cmbRelType = ComboBox:New {
                        right = 1,
                        width = 100,
                        height = model.B_HEIGHT,
                        parent = relTypePanel,
                        items = setRelTypes,
                    }
                end
                if teamAttr then
                    self.stackAttrOptions.teamPanel = TeamPanel:New {
                        parent = self.stackAttrOptions,
                    }
                end
                if typeAttr then
                    self.stackAttrOptions.typePanel = TypePanel:New {
                        parent = self.stackAttrOptions,
                    }
                end
            end
        end
    }
    self.cmbAttrType:Select(1)
end

function UnitAttrPanel:UpdateModel(attr)
    attr.id = self.cmbAttrType.selected
    local numeric = false
    local set = false
    local teamAttr = false
    local typeAttr = false

    if attr.id == 1 or attr.id == 2 then
        numeric = true
    end
    if attr.id == 3 or attr.id == 4 then
        set = true
    end

    if attr.id == 3 then
        typeAttr = true
    end

    if attr.id == 4 then
        teamAttr = true
    end
    local relTypePanel = self.stackAttrOptions.children[1]
    local cmbRelType = relTypePanel.children[2]
    attr.relType = cmbRelType.selected
    if teamAttr then
        attr.team = {}
        self.stackAttrOptions.teamPanel:UpdateModel(attr.team)
    end
    if typeAttr then
        attr.unitType = {}
        self.stackAttrOptions.typePanel:UpdateModel(attr.type)
    end
    if numeric then
        attr.numeric = {}
        self.stackAttrOptions.numericPanel:UpdateModel(attr.numeric)
    end
end

function UnitAttrPanel:UpdatePanel(attr)
    local attrTypeId = attr.id
    self.cmbAttrType:Select(attr.id)

    local numeric = false
    local set = false
    local teamAttr = false
    local typeAttr = false

    if attrTypeId == 1 or attrTypeId == 2 then
        numeric = true
    end
    if attrTypeId == 3 or attrTypeId == 4 then
        set = true
    end

    if attrTypeId == 3 then
        typeAttr = true
    end

    if attrTypeId == 4 then
        teamAttr = true
    end
    local relTypePanel = self.stackAttrOptions.children[1]
    local cmbRelType = relTypePanel.children[2]
    cmbRelType:Select(attr.relType)

    if teamAttr then
        self.stackAttrOptions.teamPanel:UpdatePanel(attr.team)
    end
    if typeAttr then
        self.stackAttrOptions.typePanel:UpdatePanel(attr.type)
    end
    if numeric then
        self.stackAttrOptions.numericPanel:UpdatePanel(attr.numeric)
    end
end
