local C_HEIGHT = 16
local B_HEIGHT = 26
local SCENEDIT_IMG_DIR = LUAUI_DIRNAME .. "images/scenedit/"
local model = SCEN_EDIT.model

VariableWindow = Window:Inherit {
    classname = "window",
    clientWidth = 300,
    clientHeight = 250,
    minimumSize = {150,200},
    x = 500,
    y = 300,
    variable = nil, --required
    _properties = nil,
    _cmbType = nil,
    _variablePanel = nil,
}

local this = VariableWindow
local inherited = this.inherited

function VariableWindow:New(obj)
    local btnOk = Button:New {
        caption='OK',
        width='40%',
        x = 1,
        bottom = 1,
        height = B_HEIGHT,
    }
    local btnCancel = Button:New {
        caption='Close',
        width='40%',
        x = '50%',
        bottom = 1,
        height = B_HEIGHT,
        OnClick={function() obj:Dispose() end}
    }
    obj._properties = StackPanel:New {
        itemMargin = {0, 0, 0, 0},
        x = 1,
        y = 1,
        right = 1,
        autosize = true,
        resizeItems = false,
    }
    obj.children = {
        ScrollPanel:New {
            x = 1,
            y = 15,
            right = 5,
            height = 80,
            children = { 
                obj._properties,
            },
        },
        btnOk,
        btnCancel,
    }

    obj = inherited.New(self, obj)
    MakeConfirmButton(obj, btnOk)
    obj:Populate()
    return obj
end

function VariableWindow:UpdatePanel(variable)
    self.edValue.text = variable.name
	self.variable = variable
	local varType = variable.type
	self.variablePanel[varType]:UpdatePanel(variable.value)   
end

function VariableWindow:UpdateModel(variable)
    variable.name = self.edValue.text
	local newVariableType = self.cmbType.items[self.cmbType.selected]
	local typeChanged = false
	if variable.type ~= newVarType then
		typeChanged = true
	end
	variable.type = newVariableType
    variable.value = {}
	self.variablePanel[variable.type]:UpdateModel(self.variable.value)
	
--[[	if typeChanged then
		model:RemoveVariable(variable.id)
		newVariable = model:NewVariable(variable.type)
		newVariable.value = variable.value
		newVariable.name = variable.name
	end--]]
end

function VariableWindow:Populate()
    self._properties:ClearChildren()

    local stackNamePanel = MakeComponentPanel(self._properties)
    local lblName = Label:New {
        caption = "Name:",
        right = 100 + 10,
        x = 1,
        parent = stackNamePanel,
    }
    self.edValue = EditBox:New {
        text = self.variable.name,
        right = 1,
        width = 100,
        height = B_HEIGHT,
        parent = stackNamePanel,
    }

    local stackTypePanel = MakeComponentPanel(self._properties)
    local lblType = Label:New {
        caption = "Type:",
        right = 100 + 10,
        x = 1,
        parent = stackTypePanel,
    }
    self.variablePanel = StackPanel:New {
        itemMargin = {0, 0, 0, 0},
        y = 20,
        x = 1,
        right = 1,
        autosize = true,
        resizeItems = false,
        padding = {0, 0, 0, 0}
    }
    local sp = ScrollPanel:New {
        x = 1,
        y = 90,
        bottom = 2 * C_HEIGHT,
        right = 5,
        parent = self,
        children = {
            self.variablePanel,
        },
    }
    self.cmbType = ComboBox:New {
        right = 1,
        width = 100,
        height = B_HEIGHT,
        items = model.variableTypes,
        parent = stackTypePanel,
        OnSelectItem = {
            function(object, itemIdx, selected)	
                if selected and itemIdx > 0 then
					self.variablePanel:ClearChildren()
			
                    local typeId = itemIdx
					local inputType = model.variableTypes[typeId] 
                    local subPanel = SCEN_EDIT.createNewPanel(inputType, self.variablePanel)
					if subPanel then
						self.variablePanel[inputType] = subPanel
						MakeSeparator(self.variablePanel)
					end
                end
            end
        },
    }
	self.cmbType:Select(-1)
    self.cmbType:Select(GetIndex(model.variableTypes, self.variable.type))
end
