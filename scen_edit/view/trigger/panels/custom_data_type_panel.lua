SB.Include(SB_VIEW_FIELDS_DIR .. "field.lua")

CustomDataTypeField = Field:extends{}

function CustomDataTypeField:init(field)
    self.width = 200

    Field.init(self, field)

    self.btnCustomDataType = Button:New {
        caption = "Custom dataType",
        width = self.width,
        height = self.height,
        OnClick = {
            function()
                local mode = 'add'
                if self.value then
                    mode = 'edit'
                end
                local customDataTypeWindow = CustomDataTypeWindow({
                    mode = mode,
                    dataType = self.dataType,
                    element = self.value,
                    trigger = self.trigger,
                    params = self.params,

                    OnConfirm = {
                        function(element)
                            self:Set(element)
                        end
                    },
                })
                -- parentWindow = self.parent.parent.parent,
                -- SB.MakeWindowModal(customDataTypeWindow.window, self.parent)
            end
        },
    }

    self.components = {
        self.btnCustomDataType
    }
end

------------------
-- Window
------------------
SB.Include(Path.Join(SB_VIEW_TRIGGER_DIR, "abstract_trigger_element_window.lua"))

CustomDataTypeWindow = AbstractTriggerElementWindow:extends{}

function CustomDataTypeWindow:init(opts)
    self.dataType = opts.dataType
    AbstractTriggerElementWindow.init(self, opts)
end

function CustomDataTypeWindow:GetValidElementTypes()
    return SB.CreateNameMapping({SB.metaModel:GetCustomDataType(self.dataType.type)})
end

function CustomDataTypeWindow:GetWindowCaption()
    if self.mode == 'add' then
        return "New " .. self.dataType.type
    elseif self.mode == 'edit' then
        return "Edit " .. self.dataType.type
    end
end
