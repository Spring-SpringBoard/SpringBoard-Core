PositionPanel = AbstractTypePanel:extends{}

function PositionPanel:init(parent, sources)
    self:super('init', 'position', parent, sources)
end

function PositionPanel:MakePredefinedOpt()
    --PREDEFINED
    local stackPositionPanel = MakeComponentPanel(self.parent)
    self.cbPredefinedPosition = Checkbox:New {
        caption = "Predefined position: ",
        right = 100 + 10,
        x = 1,
        checked = false,
        parent = stackPositionPanel,
    }
    table.insert(self.radioGroup, self.cbPredefinedPosition)
    self.btnPredefinedPosition = Button:New {
        caption = '...',
        right = 40,
        width = 60,
        height = SCEN_EDIT.conf.B_HEIGHT,
        parent = stackPositionPanel,
        position = nil,
    }
    self.btnPredefinedPosition.OnClick = {
        function()
            SCEN_EDIT.stateManager:SetState(SelectPositionState(self.btnPredefinedPosition))
        end
    }
    self.btnPredefinedPosition.OnSelectPosition = {
        function(position)
            self.btnPredefinedPosition.position = position
            self.btnPredefinedPosition.caption = 'pos'
            self.btnPredefinedPosition.tooltip = "(" .. tostring(position.x) .. ", " .. tostring(position.y) .. ", " .. tostring(position.z) .. ")"
            self.btnPredefinedPosition:Invalidate()
            if not self.cbPredefinedPosition.checked then 
                self.cbPredefinedPosition:Toggle()
            end
        end
    }
    self.btnPredefinedPositionZoom = Button:New {
        caption = "",
        right = 1,
        width = SCEN_EDIT.conf.B_HEIGHT,
        height = SCEN_EDIT.conf.B_HEIGHT,
        parent = stackPositionPanel,
        padding = {0, 0, 0, 0},
        children = {
            Image:New { 
                tooltip = "Select position", 
                file=SCEN_EDIT_IMG_DIR .. "search.png", 
                height = SCEN_EDIT.conf.B_HEIGHT, 
                width = SCEN_EDIT.conf.B_HEIGHT,
                padding = {0, 0, 0, 0},
                margin = {0, 0, 0, 0},
            },
        },
        OnClick = {
            function()
                local position = self.btnPredefinedPosition.position
                if position ~= nil then
                    Spring.MarkerAddPoint(position.x, position.y, position.z, "")
                end
            end
        }
    }
end

function PositionPanel:UpdateModel(field)
    if self.cbPredefinedPosition and self.cbPredefinedPosition.checked and self.btnPredefinedPosition.position ~= nil then
        field.type = "pred"
        field.id = self.btnPredefinedPosition.position
        return true
    elseif self.cbSpecialPosition and self.cbSpecialPosition.checked then
        field.type = "spec"
        field.name = self.cmbSpecialPosition.items[self.cmbSpecialPosition.selected]
        return true
    end
    return self:super('UpdateModel', field)
end

function PositionPanel:UpdatePanel(field)
    if field.type == "pred" then
        if not self.cbPredefinedPosition.checked then
            self.cbPredefinedPosition:Toggle()
        end
        CallListeners(self.btnPredefinedPosition.OnSelectPosition, field.id)
        return true
    elseif field.type == "spec" then
        if not self.cbSpecialPosition.checked then
            self.cbSpecialPosition:Toggle()
        end
        self.cmbSpecialPosition:Select(1) --TODO:fix it
        return true
    end
    return self:super('UpdatePanel', field)
end
