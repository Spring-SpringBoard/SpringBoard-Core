local Chili = WG.Chili
local C_HEIGHT = 16
local B_HEIGHT = 26
local SCENEDIT_IMG_DIR = LUAUI_DIRNAME .. "images/scenedit/"

VariableWindow = Chili.Window:Inherit {
    classname = "window",
    clientWidth = 300,
    clientHeight = 250,
    minimumSize = {150,200},
    x = 500,
    y = 300,
    model = nil, --required
    variable = nil, --required
    _properties = nil,
    _cmbType = nil,
    _variablePanel = nil,
}

local this = VariableWindow
local inherited = this.inherited

function VariableWindow:New(obj)
    local btnOk = Chili.Button:New {
        caption='OK',
        width='40%',
        x = 1,
        bottom = 1,
        height = B_HEIGHT,
        OnClick={function() obj:Dispose() end}
    }
    local btnCancel = Chili.Button:New {
        caption='Close',
        width='40%',
        x = '50%',
        bottom = 1,
        height = B_HEIGHT,
        OnClick={function() obj:Dispose() end}
    }
    obj._properties = Chili.StackPanel:New {
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
            height = 80,
            children = { 
                obj._properties,
            },
        },
        btnOk,
        btnCancel,
    }

    obj = inherited.New(self, obj)
    obj:Populate()
    return obj
end

function VariableWindow:UpdateVariable()
end

function VariableWindow:Populate()
    self._properties:ClearChildren()

    local stackNamePanel = MakeComponentPanel(self._properties)
    local lblName = Chili.Label:New {
        caption = "Name:",
        right = 100 + 10,
        x = 1,
        parent = stackNamePanel,
    }
    local edValue = Chili.EditBox:New {
        text = self.variable.name,
        right = 1,
        width = 100,
        height = B_HEIGHT,
        parent = stackNamePanel,
    }

    local stackTypePanel = MakeComponentPanel(self._properties)
    local lblType = Chili.Label:New {
        caption = "Type:",
        right = 100 + 10,
        x = 1,
        parent = stackTypePanel,
    }
    local variablePanel = Chili.StackPanel:New {
        itemMargin = {0, 0, 0, 0},
        y = 20,
        x = 1,
        right = 1,
        autosize = true,
        resizeItems = false,
        padding = {0, 0, 0, 0}
    }
    self._variablePanel = variablePanel
    local sp = Chili.ScrollPanel:New {
        x = 1,
        y = 90,
        bottom = 2 * C_HEIGHT,
        right = 5,
        parent = self,
        children = {
            self._variablePanel,
        },
    }
    self._cmbType = ComboBox:New {
        right = 1,
        width = 100,
        height = B_HEIGHT,
        items = self.model.variableTypes,
        parent = stackTypePanel,
        OnSelectItem = {
            function(obj,itemIdx,selected)
                if selected and itemIdx > 0 then
                    local typeId = itemIdx
                    variablePanel:ClearChildren()

                    if typeId == 1 then
                        local stackUnitPanel = MakeComponentPanel(variablePanel)
                        local lblInitialUnit = Chili.Label:New {
                            caption = "Initial unit: ",
                            right = 100 + 10,
                            x = 1,
                            parent = stackUnitPanel,
                        }
                        local btnInitialUnit = Chili.Button:New {
                            caption = '...',
                            right = 1,
                            width = 100,
                            height = B_HEIGHT,
                            parent = stackUnitPanel,
                            unitId = nil,
                        }
                        btnInitialUnit.OnClick = {
                            function() 
                                SelectUnit(btnInitialUnit)
                            end
                        }
                        btnInitialUnit.OnSelectUnit = 
                        function(unitId)
                            btnInitialUnit.unitId = unitId
                            btnInitialUnit.caption = "Unit id=" .. unitId
                            btnInitialUnit:Invalidate()
                        end
                    end
                    if typeId == 2 then
                        local stackTeamPanel = MakeComponentPanel(variablePanel)
                        local lblInitialTeam = Chili.Label:New {
                            caption = "Initial team: ",
                            right = 100 + 10,
                            x = 1,
                            parent = stackTeamPanel,
                        }
                        local playerNames, playerTeamIds = GetTeams()
                        local cmbInitialTeam = ComboBox:New {
                            right = 1,
                            width = 100,
                            height = B_HEIGHT,
                            parent = stackTeamPanel,
                            items = playerNames,
                            playerTeamIds = playerTeamIds,
                        }
                    end
                    if typeId == 3 then
                        local stackAreaPanel = MakeComponentPanel(variablePanel)
                        local lblInitialArea = Chili.Label:New {
                            caption = "Initial area: ",
                            right = 100 + 10,
                            x = 1,
                            parent = stackAreaPanel,
                        }
                        local btnInitialArea = Chili.Button:New {
                            caption = '...',
                            right = 1,
                            width = 100,
                            height = B_HEIGHT,
                            parent = stackAreaPanel,
                            areaId = nil,
                        }
                        btnInitialArea.OnClick = {
                            function() 
                                SelectArea(btnInitialArea)
                            end
                        }
                        btnInitialArea.OnSelectArea = 
                        function(areaId) 
                            btnInitialArea.areaId = areaId
                            btnInitialArea.caption = "Area id=" .. areaId
                            btnInitialArea:Invalidate()
                        end
                    end
                    if typeId == 4 or typeId == 5 then
                        local stackValuePanel = MakeComponentPanel(variablePanel)
                        local lblInitialValue = Chili.Label:New {
                            caption = "Initial value:",
                            right = 100 + 10,
                            x = 1,
                            parent = stackValuePanel,
                        }
                        local initialTxt = ""
                        if typeId == 4 then
                            initialTxt = "some text"
                        elseif typeId == 5 then
                            initialTxt = "0"
                        end
                        local edInitialValue = Chili.EditBox:New {
                            text = initialTxt,
                            right = 1,
                            width = 100,
                            parent = stackValuePanel,
                        }
                    end
                    if typeId == 6 then
                        local stackValuePanel = MakeComponentPanel(variablePanel)
                        local lblInitialValue = Chili.Label:New {
                            caption = "Initial value:",
                            right = 100 + 10,
                            x = 1,
                            parent = stackValuePanel,
                        }

                        local cbInitialValue = Chili.Checkbox:New {                        
                            caption = "True",
                            right = 1,
                            width = 100,
                            parent = stackValuePanel,
                            checked = false,
                        }
                    end
                end
            end
        },
    }
    self._cmbType:SelectItem(self.variable.type)
end
