SB.Include(SB_VIEW_FIELDS_DIR .. "field.lua")
SB.Include(SB_STATE_DIR .. "select_object_type_state.lua")

ObjectTypeField = Field:extends{}
function ObjectTypeField:Update()
    self.lblValue:SetCaption(self:GetCaption())
end

function ObjectTypeField:Validate(value)
    if value == nil then
        return Field.Validate(self, value)
    end
    if self.bridge.ObjectDefs and self.bridge.ObjectDefs[value] then
        return true, value
    end
end

function ObjectTypeField:init(field)
    self:__SetDefault("width", 200)

    Field.init(self, field)

    self.lblValue = Label:New {
        caption = self:GetCaption(),
        width = "100%",
        right = 5,
        y = 5,
        align = "right",
    }
    self.lblTitle = Label:New {
        caption = self.title,
        x = 10,
        y = 5,
        autosize = true,
    }

    self.OnSelectObjectType = function(objectTypeID)
        self:Set(objectTypeID, self.button)
    end

    self.button = Button:New {
        caption = "",
        width = self.width,
        height = self.height,
        padding = {0, 0, 0, 0,},
        tooltip = self.tooltip,
        MouseDown = function(obj, x, y, btn, ...) -- Overrides Chili.Button.MouseDown
            if btn == 1 then
                return Chili.Button.MouseDown(obj, x, y, btn, ...)
            end
        end,
        OnClick = {
            function(...)
                SB.stateManager:SetState(self.bridge.SelectObjectTypeState(self.OnSelectObjectType))
            end
        },
        children = {
            self.lblValue,
            self.lblTitle,
        },
    }

    self.components = {
        self.button,
        self.btnZoom,
    }
end

function ObjectTypeField:GetCaption()
    if self.value ~= nil then
        return "ID=" .. self.value
    else
        return "None"
    end
end

-- Custom object classes
UnitTypeField = ObjectTypeField:extends{}
function UnitTypeField:init(...)
    ObjectTypeField.init(self, ...)
    self.bridge = unitBridge
end

FeatureTypeField = ObjectTypeField:extends{}
function FeatureTypeField:init(...)
    ObjectTypeField.init(self, ...)
    self.bridge = featureBridge
end
