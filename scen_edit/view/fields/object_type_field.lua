SB.Include(Path.Join(SB.DIRS.SRC, 'view/fields/field.lua'))
SB.Include(Path.Join(SB.DIRS.SRC, 'state/select_object_type_state.lua'))

--- ObjectTypeField module.

--- ObjectTypeField class. Used to represent object types (UnitTypeField and FeatureTypeField).
-- @type ObjectTypeField
ObjectTypeField = Field:extends{}

function ObjectTypeField:Update()
    self.lblValue:SetCaption(self:GetCaption())
end

function ObjectTypeField:Validate(value)
    if self.bridge.ObjectDefs and self.bridge.ObjectDefs[value] then
        return true, value
    end
end

--- ObjectTypeField constructor.
-- It's possible to use this directly, by specifying the bridge parameter.
-- Alternatively, there are: UnitTypeField and FeatureTypeField classes.
-- @function ObjectField()
-- @see field.Field
-- @see model.ObjectBridge
-- @tparam table opts Table
-- @tparam string opts.title Title.
-- @param opts.bridge Object bridge.
-- @usage
-- -- using the bridge parameter
-- ObjectTypeField({
--     name = "myUnitTypeField",
--     bridge = unitBridge,
--     title = "My unit type",
-- })
-- -- Using the generated field class
-- FeatureTypeField({
--     name = "myFeatureTypeField",
--     title = "My feature type",
-- })
function ObjectTypeField:init(field)
    self:__SetDefault("width", 200)
    self:__SetDefault("title", "")

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
                SB.stateManager:SetState(
                    SelectObjectTypeState(self.bridge,
                                      self.OnSelectObjectType)
                )
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

-- Make this usable for other elements.
-- Perhaps create a class method that just takes the ID as param?
function ObjectTypeField:GetCaption()
    if self.value == nil then
        return "None"
    end

    if not self.bridge.ObjectDefs then
        return "ID=" .. self.value
    end

    local def = self.bridge.ObjectDefs[self.value]
    if not def then
        return "ID=" .. self.value
    end

    -- FIXME: Use a utility for extracting Spring def names
    return "Def: " .. tostring(def.name)
end

for name, bridge in pairs(ObjectBridge.GetObjectBridges()) do
    if name == "unit" or name == "feature" then
        local f = ObjectTypeField:extends{}
        function f:init(opts)
            opts.bridge = bridge
            ObjectTypeField.init(self, opts)
        end
        local fname = String.Capitalize(name) .. "TypeField"
        local g = getfenv()
        g[fname] = f
    end
end
