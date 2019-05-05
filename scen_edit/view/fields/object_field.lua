--- ObjectField module
SB.Include(SB_VIEW_FIELDS_DIR .. "field.lua")
SB.Include(SB_STATE_DIR .. "select_object_state.lua")

--- ObjectField class. Used to represent various map objects (e.g. Unit).
-- @type ObjectField
ObjectField = Field:extends{}

function ObjectField:Update()
    self.lblValue:SetCaption(self:GetCaption())
end

function ObjectField:Validate(value)
    local springID = self.bridge.getObjectSpringID(value)
    if springID and self.bridge.ValidObject(springID) then
        return true, value
    end
end

--- ObjectField constructor.
-- It's possible to use this directly, by specifying the bridge parameter.
-- Alternatively, each ObjectBridge class should have a dynamically generated Field.
-- Builtin fields are: UnitField, FeatureField, AreaField and PositionField.
-- @function ObjectField()
-- @see field.Field
-- @see model.ObjectBridge
-- @tparam table opts Table
-- @tparam string opts.title Title.
-- @param opts.bridge Object bridge.
-- @usage
-- -- using the bridge parameter
-- ObjectField({
--     name = "myUnitField",
--     bridge = unitBridge,
--     title = "My unit",
-- })
-- -- Using the generated field class
-- FeatureField({
--     name = "myFeatureField",
--     title = "My feature",
-- })
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
                SB.stateManager:SetState(
                    SelectObjectState(self.bridge,
                                      self.OnSelectObject)
                )
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
                if springID and self.bridge.ValidObject(springID) then
                    local pos
                    if self.bridge == positionBridge then
                        pos = springID
                    else
                        pos = self.bridge.s11n:Get(springID, "pos")
                    end
                    SB.view.selectionManager:Select({
                        [self.bridge.name] = {springID}
                    })
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
        if self.bridge == positionBridge then
            return string.format("(%.1f,%.1f,%.1f)",
                   self.value.x, self.value.y, self.value.z)
        else
            return self.value
        end
    else
        return "None"
    end
end

for name, bridge in pairs(ObjectBridge.GetObjectBridges()) do
    local f = ObjectField:extends{}
    function f:init(opts)
        opts.bridge = bridge
        ObjectField.init(self, opts)
    end
    local fname = String.Capitalize(name) .. "Field"
    local g = getfenv()
    g[fname] = f
end
