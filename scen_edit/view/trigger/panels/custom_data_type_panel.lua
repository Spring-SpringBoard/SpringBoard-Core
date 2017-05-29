CustomDataTypePanel = AbstractTypePanel:extends{}

function CustomDataTypePanel:MakePredefinedOpt()
    local stackValuePanel = MakeComponentPanel(self.parent)
    self.cbPredefined = Checkbox:New {
        caption = "Predefined value: ",
        right = 100 + 10,
        x = 1,
        checked = true,
        parent = stackValuePanel,
    }
    table.insert(self.radioGroup, self.cbPredefined)
    self.btnPredefined = Button:New {
        caption = 'Data type',
        right = 1,
        width = 100,
        parent = stackValuePanel,
        height = SB.conf.B_HEIGHT,
        data = {},
    }
    self.btnPredefined.OnClick = {
        function()
            local mode = 'add'
            if #self.btnPredefined.data > 0 then
                mode = 'edit'
            end
            CustomDataTypeWindow({
                parentWindow = self.parent.parent.parent,
                mode = mode,
                dataType = self.dataType,
                parentObj = self.btnPredefined.data,
                element = self.btnPredefined.data[1],
                cbExpressions = self.cbPredefined,
                btnExpressions = self.btnPredefined,
                trigger = self.trigger,
                params = self.params,
            })
        end
    }
end

function CustomDataTypePanel:UpdateModel(field)
    if self.cbPredefined and self.cbPredefined.checked and
        self.btnPredefined.data ~= nil  and #self.btnPredefined.data ~= 0 then
        field.type = "pred"
        field.value = self.btnPredefined.data
        return true
    end
    return self:super('UpdateModel', field)
end

function CustomDataTypePanel:UpdatePanel(field)
    if field.type == "pred" then
        if not self.cbPredefined.checked then
            self.cbPredefined:Toggle()
        end
        self.btnPredefined.data = field.expr
        local tooltip = SB.humanExpression(self.btnPredefined.data[1], "condition")
        self.btnPredefined.tooltip = tooltip
        return true
    end
    return self:super('UpdatePanel', field)
end

------------------
-- Window
------------------
SB.Include(Path.Join(SB_VIEW_TRIGGER_DIR, "abstract_trigger_element_window.lua"))

CustomDataTypeWindow = AbstractTriggerElementWindow:extends{}

function CustomDataTypeWindow:GetValidElementTypes()
    return {SB.metaModel:GetCustomDataType(self.dataType.type)}
end

function CustomDataTypeWindow:GetWindowCaption()
    if self.mode == 'add' then
        return "New expression of type " .. self.dataType.type
    elseif self.mode == 'edit' then
        return "Edit expression of type " .. self.dataType.type
    end
end

function CustomDataTypeWindow:AddParent()
    table.insert(self.parentObj, self.element)
end
