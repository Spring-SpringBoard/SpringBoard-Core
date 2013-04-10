AreaPanel = {
}

function AreaPanel:New(obj)
    obj = obj or {}
    setmetatable(obj, self)
    self.__index = self
    obj:Initialize()
    return obj
end

function AreaPanel:Initialize()
    local radioGroup = {}
    local stackAreaPanel = MakeComponentPanel(self.parent)
    self.cbPredefinedArea = Checkbox:New {
        caption = "Predefined area: ",
        right = 100 + 10,
        x = 1,
        checked = false,
        parent = stackAreaPanel,
    }
    table.insert(radioGroup, self.cbPredefinedArea)
    self.btnPredefinedArea = Button:New {
        caption = '...',
        right = 40,
        width = 60,
        height = SCEN_EDIT.conf.B_HEIGHT,
        parent = stackAreaPanel,
        areaId = nil,
    }
    self.btnPredefinedArea.OnClick = {
        function()
            SCEN_EDIT.stateManager:SetState(SelectAreaState(self.btnPredefinedArea))
        end
    }
    self.btnPredefinedArea.OnSelectArea = {
        function(areaId) 
            self.btnPredefinedArea.areaId = areaId
            self.btnPredefinedArea.caption = "Area id=" .. areaId
            self.btnPredefinedArea:Invalidate()
            if not self.cbPredefinedArea.checked then 
                self.cbPredefinedArea:Toggle()
            end
        end
    }
    self.btnPredefinedAreaZoom = Button:New {
        caption = "",
        right = 1,
        width = SCEN_EDIT.conf.B_HEIGHT,
        height = SCEN_EDIT.conf.B_HEIGHT,
        parent = stackAreaPanel,
        padding = {0, 0, 0, 0},
        children = {
            Image:New { 
                tooltip = "Select area", 
                file=SCEN_EDIT_IMG_DIR .. "search.png", 
                height = SCEN_EDIT.conf.B_HEIGHT, 
                width = SCEN_EDIT.conf.B_HEIGHT,
                padding = {0, 0, 0, 0},
                margin = {0, 0, 0, 0},
            },
        },
        OnClick = {
            function()
                if self.btnPredefinedArea.areaId ~= nil then
                    local area = SCEN_EDIT.model.areaManager:getArea(self.btnPredefinedArea.areaId)
                    if area ~= nil then
                        local x = (area[1] + area[3]) / 2
                        local z = (area[2] + area[4]) / 2
                        local y = Spring.GetGroundHeight(x, z)
                        Spring.SetCameraTarget(x, y, z)
                    end
                end
            end
        }
    }

    --SPECIAL AREA, i.e TRIGGER
    local stackAreaPanel = MakeComponentPanel(self.parent)
    self.cbSpecialArea = Checkbox:New {
        caption = "Special area: ",
        right = 100 + 10,
        x = 1,
        checked = true,
        parent = stackAreaPanel,
    }
    table.insert(radioGroup, self.cbSpecialArea)
    self.cmbSpecialArea = ComboBox:New {
        right = 1,
        width = 100,
        height = SCEN_EDIT.conf.B_HEIGHT,
        parent = stackAreaPanel,
        items = { "Trigger area" },
    }
    self.cmbSpecialArea.OnSelect = {
        function(obj, itemIdx, selected)
            if selected and itemIdx > 0 then
                if not self.cbSpecialArea.checked then
                    self.cbSpecialArea:Toggle()
                end
            end
        end
    }

   --VARIABLE
    self.cbVariable, self.cmbVariable = MakeVariableChoice("area", self.parent)
    if self.cbVariable then
        table.insert(radioGroup, self.cbVariable)
    end
    
    --EXPRESSION
    self.cbExpression, self.btnExpression = SCEN_EDIT.AddExpression("area", self.parent)
    if self.cbExpression then
        table.insert(radioGroup, self.cbExpression)
    end
    SCEN_EDIT.MakeRadioButtonGroup(radioGroup)
end

function AreaPanel:UpdateModel(field)
    if self.cbPredefinedArea.checked then
        field.type = "pred"
        field.id = self.btnPredefinedArea.areaId
    elseif self.cbSpecialArea.checked then
        field.type = "spec"
        field.name = self.cmbSpecialArea.items[self.cmbSpecialArea.selected]
    elseif self.cbVariable and self.cbVariable.checked then
        field.type = "var"
        field.id = self.cmbVariable.variableIds[self.cmbVariable.selected]
    elseif self.cbExpression and self.cbExpression.checked then
        field.type = "expr"
        field.expr = self.btnExpression.data
    end
end

function AreaPanel:UpdatePanel(field)
    if field.type == "pred" then
        if not self.cbPredefinedArea.checked then
            self.cbPredefinedArea:Toggle()
        end
        CallListeners(self.btnPredefinedArea.OnSelectArea, field.id)
    elseif field.type == "spec" then
        if not self.cbSpecialArea.checked then
            self.cbSpecialArea:Toggle()
        end
        self.cmbSpecialArea:Select(1) --TODO:fix it                
    elseif field.type == "var" then
        if not self.cbVariable.checked then
            self.cbVariable:Toggle()
        end
        for i = 1, #self.cmbVariable.variableIds do
            local variableId = self.cmbVariable.variableIds[i]
            if variableId == field.id then
                self.cmbVariable:Select(i)
                break
            end
        end
    elseif field.type == "expr" then
        if not self.cbExpression.checked then
            self.cbExpression:Toggle()
        end
        self.btnExpression.data = field.expr
    end
end
