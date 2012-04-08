local Chili = WG.Chili
local SCENEDIT_IMG_DIR = LUAUI_DIRNAME .. "images/scenedit/"
local model = SCEN_EDIT.model

ActionWindow = Chili.Window:Inherit {
    classname = "window",	
	resizable = false,
	clientWidth = 300,
	clientHeight = 300,
	x = 500,
	y = 300,
    trigger = nil, --required
	triggerWindow = nil, --required
	mode = nil, --'add' or 'edit'
}

local this = ActionWindow 
local inherited = this.inherited

function ActionWindow:New(obj)
	obj.triggerWindow.disableChildrenHitTest = true	
    obj.btnOk = Chili.Button:New {
        caption = "OK",
        height = model.B_HEIGHT,
        width = "40%",
        x = "5%",
        y = "7%",
    }
    obj.btnCancel = Chili.Button:New {
        caption = "Cancel",
        height = model.B_HEIGHT,
        width = "40%",
        x = "55%",
        y = "7%",
    }	
	obj.actionPanel = Chili.StackPanel:New {
        itemMargin = {0, 0, 0, 0},
        x = 1,
        y = 1,
        right = 1,
        autosize = true,
        resizeItems = false,
        padding = {0, 0, 0, 0}
    }
    obj.cmbActionTypes = ComboBox:New {
        items = GetField(obj.model.actionTypes, "humanName"),
		actionTypes = GetField(obj.model.actionTypes, "name"),
        height = model.B_HEIGHT,
        width = "60%",
        y = "20%",
        x = '20%',
    }
	obj.cmbActionTypes.OnSelectItem = {
		function(object, itemIdx, selected)
			if selected and itemIdx > 0 then
				obj.actionPanel:ClearChildren()
				local actName = obj.cmbActionTypes.actionTypes[itemIdx]
				local unitAct = false
				local triggerAct = false
				local typeAct = false
				local orderAct = false
				local areaAct = false

				if actName == "SPAWN_UNIT" then
					typeAct = true
				end
				if actName == "ISSUE_ORDER" or actName == "DESTROY_UNIT" or actName == "MOVE_UNIT" or actName == "TRANSFER_UNIT" then
					unitAct = true
				end
				if actName == "SPAWN_UNIT" or actName == "MOVE_UNIT" then
					areaAct = true
				end
				if actName == "ISSUE_ORDER" then
					orderAct = true
				end
				if actName == "ENABLE_TRIGGER" or actName == "DISABLE_TRIGGER" then
					triggerAct = true
				end

				if unitAct then
					obj.actionPanel.unitPanel = UnitPanel:New {
						parent = obj.actionPanel,
					}					
					MakeSeparator(obj.actionPanel)					
				end
				if areaAct then
					obj.actionPanel.areaPanel = AreaPanel:New {
						parent = obj.actionPanel,
					}			
					MakeSeparator(obj.actionPanel)
				end
				if triggerAct then					
					obj.actionPanel.triggerPanel = TriggerPanel:New {
						parent = obj.actionPanel,
					}
					MakeSeparator(obj.actionPanel)
				end
				if typeAct then
					local stackTypePanel = MakeComponentPanel(obj.actionPanel)
					local cbPredefinedType = Chili.Checkbox:New {
						caption = "Predefined type: ",
						right = 100 + 10,
						x = 1,
						checked = false,
						parent = stackTypePanel,
					}
					local btnPredefinedType = Chili.Button:New {
						caption = '...',
						right = 1,
						width = 100,
						height = model.B_HEIGHT,
						parent = stackTypePanel,
						unitTypeId = nil,
					}
					btnPredefinedType.OnClick = {
						function() 
							SelectType(btnPredefinedType)
						end
					}
					btnPredefinedType.OnSelectUnitType = { 
						function(unitTypeId)
							btnPredefinedType.unitTypeId = unitTypeId
							btnPredefinedType.caption = 
							"Type id=" .. unitTypeId
							btnPredefinedType:Invalidate()
							if not cbPredefinedType.checked then 
								cbPredefinedType:Toggle()
							end
						end
					}
					--SPECIAL TYPE, i.e TRIGGER
					local stackTypePanel = MakeComponentPanel(obj.actionPanel)
					local cbSpecialType = Chili.Checkbox:New {
						caption = "Special type: ",
						right = 100 + 10,
						x = 1,
						checked = true,
						parent = stackTypePanel,
					}
					local cmbSpecialType = ComboBox:New {
						right = 1,
						width = 100,
						height = model.B_HEIGHT,
						parent = stackTypePanel,
						items = { "Trigger unit type" },
						OnSelectItem = {
							function(obj, itemIdx, selected)
								if selected and itemIdx > 0 then
									if not cbSpecialType.checked then
										cbSpecialType:Toggle()
									end
								end
							end
						},
					}
					MakeRadioButtonGroup({cbSpecialType, cbPredefinedType})
					MakeSeparator(obj.actionPanel)
				end
			end
		end
	}
	
    obj.children = {
		obj.cmbActionTypes,
		obj.btnOk,
		obj.btnCancel,
		Chili.ScrollPanel:New {
			x = 1,
			y = obj.cmbActionTypes.y + obj.cmbActionTypes.height + 80,
			bottom = 1,
			right = 5,
			children = {
				obj.actionPanel,
			},
		},
	}
	
    obj = inherited.New(self, obj)

	obj.btnCancel.OnClick = {
		function() 
			obj.triggerWindow.disableChildrenHitTest = false
			obj:Dispose()
		end
	}
	
	obj.btnOk.OnClick = {
		function()			
			if obj.mode == 'edit' then
				obj:EditAction()
				obj.triggerWindow.disableChildrenHitTest = false
				obj:Dispose()
			elseif obj.mode == 'add' then
				obj:AddAction()
				obj.triggerWindow.disableChildrenHitTest = false
				obj:Dispose()
			end
		end
	}
	
	obj.cmbActionTypes:Select(0)
	obj.cmbActionTypes:Select(1)
	if obj.mode == 'add' then
		obj.caption = "New action for - " .. obj.trigger.name
		local tw = obj.triggerWindow
		obj.x = tw.x
		obj.y = tw.y + tw.height + 5
		if tw.parent.height <= obj.y + obj.height then
			obj.y = tw.y - obj.height
		end
	elseif obj.mode == 'edit' then
		obj.cmbActionTypes:Select(GetIndex(obj.cmbActionTypes.actionTypes, obj.action.actionTypeName))
		obj:UpdatePanel()
		obj.caption = "Edit action for trigger " .. obj.trigger.name
		local tw = obj.triggerWindow
		if tw.x + tw.width + obj.width > tw.parent.width then
			obj.x = tw.x - obj.width
		else
			obj.x = tw.x + tw.width
		end
		obj.y = tw.y
	end	
	
    return obj
end

function ActionWindow:UpdatePanel()
	local actName = self.action.actionTypeName

	if actName == "SPAWN_UNIT" then
		self.actionPanel.unitTypePanel:UpdatePanel(self.action.unitType)
	end
	if actName == "ISSUE_ORDER" or actName == "DESTROY_UNIT" or actName == "MOVE_UNIT" or actName == "TRANSFER_UNIT" then
		self.actionPanel.unitPanel:UpdatePanel(self.action.unit)
	end
	if actName == "SPAWN_UNIT" or actName == "MOVE_UNIT" then
		self.actionPanel.areaPanel:UpdatePanel(self.action.area)
	end
	if actName == "ISSUE_ORDER" then
		--self.actionPanel.orderPanel:UpdatePanel(self.action.order)
	end
	if actName == "ENABLE_TRIGGER" or actName == "DISABLE_TRIGGER" then
		self.actionPanel.triggerPanel:UpdatePanel(self.action.trigger)
	end
end

function ActionWindow:UpdateModel()
	local actName = self.action.actionTypeName

	if actName == "SPAWN_UNIT" then
		self.action.unitType = {}
		self.actionPanel.unitTypePanel:UpdateModel(self.action.unitType)
	end
	if actName == "ISSUE_ORDER" or actName == "DESTROY_UNIT" or actName == "MOVE_UNIT" or actName == "TRANSFER_UNIT" then
		self.action.unit = {}
		self.actionPanel.unitPanel:UpdateModel(self.action.unit)
	end
	if actName == "SPAWN_UNIT" or actName == "MOVE_UNIT" then
		self.action.area = {}
		self.actionPanel.areaPanel:UpdateModel(self.action.area)
	end
	if actName == "ISSUE_ORDER" then
		self.action.order = {}
		--self.actionPanel.orderPanel:UpdateModel(self.action.order)
	end
	if actName == "ENABLE_TRIGGER" or actName == "DISABLE_TRIGGER" then
		self.action.trigger = {}
		self.actionPanel.triggerPanel:UpdateModel(self.action.trigger)
	end
end

function ActionWindow:EditAction()
    self.action.actionTypeName = self.cmbActionTypes.actionTypes[self.cmbActionTypes.selected]	
	self:UpdateModel()
    self.triggerWindow:Populate()
end

function ActionWindow:AddAction()
    self.action = { actionTypeName = self.cmbActionTypes.actionTypes[self.cmbActionTypes.selected] }
	self:UpdateModel()
    table.insert(self.trigger.actions, self.action)	
    self.triggerWindow:Populate()
end


