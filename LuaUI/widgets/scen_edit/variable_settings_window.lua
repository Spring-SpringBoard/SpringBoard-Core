local Chili = WG.Chili
local C_HEIGHT = 16
local B_HEIGHT = 26
local SCENEDIT_IMG_DIR = LUAUI_DIRNAME .. "images/scenedit/"
local model = SCEN_EDIT.model

VariableSettingsWindow = Chili.Window:Inherit {
    classname = "window",
    clientWidth = 300,
    clientHeight = 250,
    minimumSize = {150,200},
    x = 500,
    y = 300,
    _variables = nil,
}

local this = VariableSettingsWindow
local inherited = this.inherited

function VariableSettingsWindow:New(obj)
    local btnAddVariable = Chili.Button:New {
        caption='Add variable',
        width='40%',
        x = 1,
        bottom = 1,
        height = B_HEIGHT,
        OnClick={ 
			function() 				
				obj:AddVariable()
			end}
    }
    local btnClose = Chili.Button:New {
        caption='Close',
        width='40%',
        x = '50%',
        bottom = 1,
        height = B_HEIGHT,
    }
    obj.variablesPanel = Chili.StackPanel:New {
        itemMargin = {0, 0, 0, 0},
        x = 1,
        y = 1,
        right = 1,
        autosize = true,
        resizeItems = false,
    }
    obj.children = {
        Chili.ScrollPanel:New {
            x = 1,
            y = 15,
            right = 5,
            bottom = C_HEIGHT * 2,
            children = { 
                obj.variablesPanel
            },
        },
        btnAddVariable,
        btnClose,
    }
    btnClose.OnClick={
        function() 
            obj:Dispose() 
        end
    }
    obj = inherited.New(self, obj)
    obj:Populate()
    return obj
end

function VariableSettingsWindow:AddVariable()
    local newVariable = model:NewVariable("number")
    self:Populate()
    for i = 1, #self.variablesPanel.children do
        local panel = self.variablesPanel.children[i]
        if panel.variableId == newVariable.id then
            local btnEdit = panel.children[1]
            btnEdit:CallListeners(btnEdit.OnClick)
            break
        end
    end
end

function VariableSettingsWindow:MakeRemoveVariableWindow(variableId)
    model:RemoveVariable(variableId)
    self:Populate()
end

function VariableSettingsWindow:Populate()
    self.variablesPanel:ClearChildren()
	local variables = model:ListVariables();
    for i = 1, #variables do
        local variable = variables[i]
        local variableStackPanel = Chili.StackPanel:New {
            variableId = variable.id,
            parent = self.variablesPanel,
            width = "100%",
            height = B_HEIGHT + 8,
            orientation = "horizontal",
            padding = {0, 0, 0, 0},
            itemMarging = {0, 0, 0, 0},
            resizeItems = false,
        }
        local btnEditVariable = Chili.Button:New {
            caption = variable.name,
            right = B_HEIGHT + 10,
            x = 1,
            height = B_HEIGHT,
            _toggle = nil,
            parent = variableStackPanel,
        }
        local btnRemoveVariable = Chili.Button:New {
            caption = "",
            right = 1,
            width = B_HEIGHT,
            height = B_HEIGHT,
            parent = variableStackPanel,
            padding = {0, 0, 0, 0},
            children = {
                Chili.Image:New { 
                    tooltip = "Remove variable", 
                    file=SCENEDIT_IMG_DIR .. "list-remove.png", 
                    height = B_HEIGHT, 
                    width = B_HEIGHT,
                    padding = {0, 0, 0, 0},
                    margin = {0, 0, 0, 0},
                },
            },
            OnClick = {function() self:MakeRemoveVariableWindow(variable.id) end},
        }
            
        btnEditVariable.OnClick = {
            function() 
                local newWin = self:MakeVariableWindow(variable)
                table.insert(newWin.OnConfirm,
                    function()
                        newWin:UpdateModel(variable)
                    end
                )
                newWin:UpdatePanel(variable)
                if self.x + self.width + newWin.width > self.parent.width then
                    newWin.x = self.x - newWin.width
                else
                    newWin.x = self.x + self.width
                end
                newWin.y = self.y

                self.disableChildrenHitTest = true
                table.insert(newWin.OnDispose, 
                    function() 
                        self.disableChildrenHitTest = false
                        self:Populate()
                    end
                )
            end
        }
    end
end

function VariableSettingsWindow:MakeVariableWindow(variable)
    local variableWindow = VariableWindow:New {
        parent = self.parent,
        variable = variable,
    }
    return variableWindow
end
