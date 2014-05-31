GenericArrayPanel = AbstractTypePanel:extends{}

function GenericArrayPanel:init(type, parent, sources)
    self.subPanels = StackPanel:New {
        itemMargin = {0, 0, 0, 0},
        x = 1,
        y = 1,
        right = 1,
        autosize = true,
        resizeItems = false,
        parent = parent,
    }
    self:super('init', type, parent, sources)
    self.type = type
    self.atomicType = type:gsub("_array", "")
    self.elements = {}
end

function GenericArrayPanel:MakePredefinedOpt()
    local addPanel = MakeComponentPanel(self.parent)

    self.cbPredefinedArray = Checkbox:New {
        caption = "Predefined array: ",
        right = 100 + 10,
        x = 1,
        checked = false,
        parent = addPanel,
    }
    table.insert(self.radioGroup, self.cbPredefinedArray)
    self.btnAddElement = Button:New {
        caption = '+',
        right = 40,
        width = 60,
        height = SCEN_EDIT.conf.B_HEIGHT,
        parent = addPanel,
        OnClick= {
            function() 
                self:AddElement() 
                if not self.cbPredefinedArray.checked then 
                    self.cbPredefinedArray:Toggle()
                end
            end
        }
    }
end

function GenericArrayPanel:AddElement()
	local subPanel = SCEN_EDIT.createNewPanel(self.atomicType, self.subPanels)
    table.insert(self.elements, subPanel)
	SCEN_EDIT.MakeSeparator(self.subPanels)
end

function GenericArrayPanel:UpdateModel(field)
    if self.cbPredefinedArray and self.cbPredefinedArray.checked then
        field.type = "pred"
        field.id = {}
        for _, subPanel in pairs(self.elements) do
            local subPanelValue = {}
            subPanel:UpdateModel(subPanelValue)
            table.insert(field.id, subPanelValue)
        end
        return true
    end
    return self:super('UpdateModel', field)
end

function GenericArrayPanel:UpdatePanel(field)
    if field.type == "pred" then
        if not self.cbPredefinedArray.checked then
            self.cbPredefinedArray:Toggle()
        end
        for i, data in pairs(field.id) do
            self:AddElement()
            self.elements[i]:UpdatePanel(data)
        end
        return true
    end
    return self:super('UpdatePanel', field)
end
