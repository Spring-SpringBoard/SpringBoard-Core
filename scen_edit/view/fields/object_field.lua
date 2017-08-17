SB.Include(SB_VIEW_FIELDS_DIR .. "field.lua")
SB.Include(SB_STATE_DIR .. "select_object_state.lua")

ObjectField = Field:extends{}
function ObjectField:Update()
    self.lblValue:SetCaption(self:GetCaption())
end

function ObjectField:Validate(value)
    if value == nil then
        return Field.Validate(self, value)
    end
    local springID = self.bridge.getObjectSpringID(value)
    if springID and self.bridge.spValidObject(springID) then
        return true, value
    end
end

function ObjectField:init(field)
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
        caption = self.title or "",
        x = 10,
        y = 5,
        autosize = true,
    }

    self.OnSelectObject = function(objectID)
        self:Set(objectID, self.button)
    end

    local zoomSize = self.height
    local buttonPadding = 5

    self.button = Button:New {
        caption = "",
        width = self.width - buttonPadding - zoomSize,
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
                SB.stateManager:SetState(self.bridge.SelectObjectState(self.OnSelectObject))
            end
        },
        children = {
            self.lblValue,
            self.lblTitle,
        },
    }

    self.btnZoom = Button:New {
        caption = "",
        x = self.width - zoomSize,
        width = zoomSize,
        height = zoomSize,
        tooltip = "Select",
        padding = {2, 2, 2, 2},
        children = {
            Image:New {
                file = SB_IMG_DIR .. "position-marker.png",
                height = "100%",
                width = "100%",
            },
        },
        OnClick = {
            function()
                if self.value == nil then
                    return
                end
                local springID = self.bridge.getObjectSpringID(self.value)
                if springID and self.bridge.spValidObject(springID) then
                    local pos = self.bridge.s11n:Get(springID, "pos")
                    self.bridge.Select({springID})
                    Spring.SetCameraTarget(pos.x, pos.y, pos.z)
                end
            end
        }
    }

    self.components = {
        self.button,
        self.btnZoom,
    }
end

function ObjectField:GetCaption()
    if self.value ~= nil then
        return "ID=" .. self.value
    else
        return "None"
    end
end

-- Custom object classes
UnitField = ObjectField:extends{}
function UnitField:init(...)
    ObjectField.init(self, ...)
    self.bridge = unitBridge
end

FeatureField = ObjectField:extends{}
function FeatureField:init(...)
    ObjectField.init(self, ...)
    self.bridge = featureBridge
end

AreaField = ObjectField:extends{}
function AreaField:init(...)
    ObjectField.init(self, ...)
    self.bridge = areaBridge
end

PositionField = ObjectField:extends{}

function PositionField:init(...)
    ObjectField.init(self, ...)
    self.bridge = positionBridge
end

function PositionField:GetCaption()
    if self.value ~= nil then
        return string.format("(%.1f,%.1f,%.1f)", self.value.x, self.value.y, self.value.z)
    else
        return ObjectField.GetCaption(self)
    end
end
