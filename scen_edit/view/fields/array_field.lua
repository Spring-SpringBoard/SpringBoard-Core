--- ArrayField module.
SB.Include(Path.Join(SB.DIRS.SRC, 'view/fields/field.lua'))

--- ArrayField class.
-- @type ArrayField
ArrayField = Field:extends{}

--- ArrayField constructor.
-- @function ArrayField()
-- @see field.Field
-- @tparam table opts Table
-- @tparam[opt='Array'] string opts.title Title.
-- @tparam[opt=false] boolean opts.expand Whether to expand the field in the Editor or open it with a button.
-- @tparam[opt=true] boolean opts.canAdd Allow adding new elements with the GUI.
-- @tparam[opt=true] boolean opts.canRemove Allow removing elements with the GUI.
-- @usage
-- ArrayField({
--     name = "myArrayField",
--     type = NumericField,
--     value = {2, 1, -3},
--     canAdd = true,
--     canRemove = false,
-- })
function ArrayField:init(field)
    self:__SetDefault("width", 200)
    self:__SetDefault("canAdd", true)
    self:__SetDefault("canRemove", true)
    self:__SetDefault("value", {})

    Field.init(self, field)

    self.type = field.type

    self.btnEdit = Button:New {
        caption = self.title or "Array",
        width = self.width,
        height = self.height,
        OnClick = {
            function()
                self.arrayWindow.window:Show()
                SB.MakeWindowModal(self.arrayWindow.window, self.btnEdit)
            end
        },
    }

    self.arrayWindow = self:__MakeWindow({
        OnAddItem = {
            function(index, value)
                table.insert(self.value, index, value)
                self:Set(self.value, self.arrayWindow)
            end
        },
        OnRemoveItem = {
            function(index)
                table.remove(self.value, index)
                self:Set(self.value, self.arrayWindow)
            end
        },
        OnUpdateItem = {
            function(index, value)
                self.value[index] = value
                self:Set(self.value, self.arrayWindow)
            end
        },
        field = self,
    })
    self.arrayWindow.window:Hide()

    if self.expand then
        self.arrayWindow.window:SetPos(0, 0, self.width, self.height)
        self.components = {
            self.arrayWindow.window
        }
    else
        self.components = {
            self.btnEdit,
        }
    end
end

-- Overriden
-- Not used
function ArrayField:__GetDisplayText()
    local retStr = "{"
    for i, f in pairs(self.value) do
        if f.__GetDisplayText then
            local fText = f:__GetDisplayText()
            retStr = retStr .. fText
            if i ~= #self.value then
                retStr = retStr .. ", "
            end
        end
    end
    retStr = retStr .. "}"
    return retStr
end

-- function ArrayField:Validate(value)
--     -- Let fields do their own validation when they're created
--     -- for _, v in pairs(value) do
--     --     if not self.type.Validate(v) then
--     --         return false
--     --     end
--     -- end
--     return true, value
-- end

function ArrayField:Update(source)
    if source ~= self.arrayWindow then
        self.arrayWindow:SetValue(self.value)
    end
end

function ArrayField:__MakeWindow(tbl)
    return ArrayFieldWindow(tbl)
end


-- Popup window that allows modifying the array

SB.Include(Path.Join(SB.DIRS.SRC, 'view/editor.lua'))

ArrayFieldWindow = Editor:extends{}

function ArrayFieldWindow:init(opts)
    Editor.init(self, opts)

    self.field = opts.field
    self.OnAddItem = opts.OnAddItem
    self.OnRemoveItem = opts.OnRemoveItem
    self.OnUpdateItem = opts.OnUpdateItem

    if self.field.canAdd then
        self.btnAddItem = TabbedPanelButton({
            x = 0,
            y = 0,
            tooltip = "Add",
            children = {
                TabbedPanelImage({ file = Path.Join(SB.DIRS.IMG, 'plus.png') }),
                TabbedPanelLabel({ caption = "Add" }),
            },
            OnClick = {
                function()
                    self:__AddElement()
                end
            },
        })
    end

    self.__field_id_counter = 0
    self.__fieldsCount = 0
    self.__fieldIndex = {}

    local children = { self.btnAddItem }
    table.insert(children,
        ScrollPanel:New {
            x = 0,
            y = 80,
            bottom = 0,
            right = 0,
            borderColor = {0,0,0,0},
            horizontalScrollbar = false,
            children = { self.stackPanel },
        }
    )
    if self.field.expand then
        self:Finalize(children)
    else
        self:Finalize(children, {
            notMainWindow = true,
            buttons = { "close" },
            disposeOnClose = false
        })
    end

    self:SetValue(self.field.value)
end

function ArrayFieldWindow:SetValue(value)
    local fieldNames = {}
    for fieldName, _ in pairs(self.__fieldIndex) do
        table.insert(fieldNames, fieldName)
    end

    for _, fieldName in pairs(fieldNames) do
        self:__RemoveField(fieldName)
    end

    self.__field_id_counter = 0
    self.__fieldsCount = 0
    self.__fieldIndex = {}

    for _, v in pairs(value) do
        self:__AddElement(v, true)
    end
end

function ArrayFieldWindow:__AddElement(value, noCallback)
    self.__field_id_counter = self.__field_id_counter + 1
    local id = self.__field_id_counter
    local fieldName = "field_" .. tostring(id)

    local index = self.__fieldsCount + 1
    self.__fieldsCount = self.__fieldsCount + 1
    self.__fieldIndex[fieldName] = index

    local field = self.field.type({
        name = fieldName,
        width = self.field.width - SB.conf.B_HEIGHT - 5,
        value = value,
    })
    if self.field.canRemove then
        local btnRemove = Button:New {
            caption = "",
            width = SB.conf.B_HEIGHT,
            height = SB.conf.B_HEIGHT,
            padding = {2, 2, 2, 2},
            tooltip = "Remove",
            classname = "negative_button",
            children = {
                Image:New {
                    file = Path.Join(SB.DIRS.IMG, 'cancel.png'),
                    height = "100%",
                    width = "100%",
                },
            },
            OnClick = {
                function()
                    self:__RemoveField(fieldName)
                end
            }
        }

        local groupField = GroupField({
            field,
            Field({
                name = "btnRemove_" .. tostring(id),
                width = SB.conf.B_HEIGHT,
                components = {
                    btnRemove
                },
            })
        })
        field.removeFieldName = groupField.name
        self:AddField(groupField)
    else
        field.removeFieldName = field.name
        self:AddField(field)
    end

    self:SetInvisibleFields()

    if not noCallback then
        CallListeners(self.OnAddItem, index, self.fields[fieldName].value)
    end
end

function ArrayFieldWindow:__RemoveField(fieldName)
    -- Sometimes we want to remove the group field instead
    local removeField = self.fields[fieldName].removeFieldName
    self:RemoveField(removeField)

    local index = self.__fieldIndex[fieldName]
    self.__fieldIndex[fieldName] = nil
    self.__fieldsCount = self.__fieldsCount - 1

    self:SetInvisibleFields()

    local newFieldIndex = {}
    for name, i in pairs(self.__fieldIndex) do
        if i > index then
            newFieldIndex[name] = i - 1
        else
            newFieldIndex[name] = i
        end
    end
    self.__fieldIndex = newFieldIndex

    CallListeners(self.OnRemoveItem, index)
end

function ArrayFieldWindow:OnFieldChange(name, value)
    local index = self.__fieldIndex[name]
    CallListeners(self.OnUpdateItem, index, value)
end
