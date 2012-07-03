local Chili
Chili = WG.Chili
local C_HEIGHT = 16
local B_HEIGHT = 26

GenericArrayPanel = class()

function GenericArrayPanel:__init(parent, type)
	self.parent = parent
	self.type = type
    self:Initialize()
end

function GenericArrayPanel:Initialize()
	local radioGroup = {}
	
	--VARIABLE
    self.cbVariable, self.cmbVariable = MakeVariableChoice(self.type, self.parent)
    if self.cbVariable then
		table.insert(radioGroup, self.cbVariable)
    end
	
	self.cbExpression, self.btnExpression = SCEN_EDIT.AddExpression(self.type, self.parent)
	if self.cbExpression then
		table.insert(radioGroup, self.cbExpression)
	end
	MakeRadioButtonGroup(radioGroup)
end

function GenericArrayPanel:UpdateModel(field)
	if self.cbVariable and self.cbVariable.checked then
        field.type = "var"
        field.id = self.cmbVariable.variableIds[self.cmbVariable.selected]
    elseif self.cbExpression and self.cbExpression.checked then
        field.type = "expr"
        field.expr = self.btnExpression.data
    end
end

function GenericArrayPanel:UpdatePanel(field)
    if field.type == "var" then
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
