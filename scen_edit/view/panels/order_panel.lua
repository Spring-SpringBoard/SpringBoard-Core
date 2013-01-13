local model = SCEN_EDIT.model

OrderPanel = {
}

function OrderPanel:New(obj)
    obj = obj or {}
    setmetatable(obj, self)
    self.__index = self
    obj:Initialize()
    return obj
end

function OrderPanel:Initialize()
	local stackPanel = MakeComponentPanel(self.parent)	
    self.cmbOrderTypes = ComboBox:New {
        items = GetField(model.orderTypes, "humanName"),
		orderTypes = GetField(model.orderTypes, "name"),
        height = model.B_HEIGHT,
        width = "60%",
        y = "20%",
        x = '20%',
		parent = stackPanel,
    }
	self.orderPanel = StackPanel:New {
        itemMargin = {0, 0, 0, 0},
        x = 1,
        y = 1,
        right = 1,
        autosize = true,
        resizeItems = false,
        padding = {0, 0, 0, 0},	
		parent = self.parent,
    }
	self.cmbOrderTypes.OnSelect = {
		function(object, itemIdx, selected)
			if selected and itemIdx > 0 then
				self.orderPanel:ClearChildren()
				local ordName = self.cmbOrderTypes.orderTypes[itemIdx]
				local order = model.orderTypes[ordName]
				for i = 1, #order.input do
					local input = order.input[i]
					local subPanelName = input.name					
					if input.humanName then
						Label:New {
							parent = self.orderPanel,
							caption = input.humanName,
							x = 1,
							right = 1,
						}
					end
					local subPanel = SCEN_EDIT.createNewPanel(input.type, self.orderPanel)
					if subPanel then
						self.orderPanel[subPanelName] = subPanel
						MakeSeparator(self.orderPanel)
					end
				end
			end
		end
	}
	
	self.cmbOrderTypes:Select(0)
	self.cmbOrderTypes:Select(1)
end

function OrderPanel:UpdateModel(field)
	local ordName = self.cmbOrderTypes.orderTypes[self.cmbOrderTypes.selected]
	local order = model.orderTypes[ordName]
	field.orderTypeName = ordName
	for i = 1, #order.input do
		local input = order.input[i]
		local subPanelName = input.name
		local subPanel = self.orderPanel[subPanelName]
		if subPanel then
			field[subPanelName] = {}
			self.orderPanel[subPanelName]:UpdateModel(field[subPanelName])
		end
	end

end

function OrderPanel:UpdatePanel(field)
	local ordName = field.orderTypeName
	local order = model.orderTypes[ordName]	
	self.cmbOrderTypes:Select(GetIndex(self.cmbOrderTypes.orderTypes, ordName))
	for i = 1, #order.input do
		local input = order.input[i]
		local subPanelName = input.name
		local subPanel = self.orderPanel[subPanelName]
		if subPanel then
			subPanel:UpdatePanel(field[subPanelName])
		end
	end
end