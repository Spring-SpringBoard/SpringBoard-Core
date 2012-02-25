local Chili = WG.Chili
local C_HEIGHT = 16
local B_HEIGHT = 26
local SCENEDIT_IMG_DIR = LUAUI_DIRNAME .. "images/scenedit/"

VariableSettingsWindow = Chili.Window:Inherit {
    classname = "window",
    clientWidth = 300,
    clientHeight = 250,
    minimumSize = {150,200},
    x = 500,
    y = 300,
    model = nil, --required
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
        OnClick={function() obj:AddVariable() end}
    }
    local btnClose = Chili.Button:New {
        caption='Close',
        width='40%',
        x = '50%',
        bottom = 1,
        height = B_HEIGHT,
    }
    obj._variables = Chili.StackPanel:New {
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
                obj._variables
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
    local newVariable = self.model:NewVariable()
    self:Populate()
    for i = 1, #self._variables.children do
        local panel = self._variables.children[i]
        if panel.variableId == newVariable.id then
            local btnEdit = panel.children[1]
            btnEdit:CallListeners(btnEdit.OnClick)
            return
        end
    end
end

function VariableSettingsWindow:MakeRemoveVariableWindow(variableId)
    self.model:RemoveVariable(variableId)
    self:Populate()
end

function VariableSettingsWindow:Populate()
    self._variables:ClearChildren()
    for i = 1, #self.model.variables do
        local variable = self.model.variables[i]
        local stackVariablePanel = Chili.StackPanel:New {
            variableId = variable.id,
            parent = self._variables,
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
            parent = stackVariablePanel,
        }
        local btnRemoveVariable = Chili.Button:New {
            caption = "",
            right = 1,
            width = B_HEIGHT,
            height = B_HEIGHT,
            parent = stackVariablePanel,
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
                local newWin = MakeVariableWindow(variable)
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
                end)
            end
        }
    end
end
