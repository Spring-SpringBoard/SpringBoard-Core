SB.Include(SB_VIEW_FIELDS_DIR .. "field.lua")

TriggerDataTypeField = Field:extends{}

function TriggerDataTypeField:init(field)
    self.width = 200
    self.windowType = TriggerDataTypeWindow

    Field.init(self, field)

    self.btnDataType = Button:New {
        caption = "Custom dataType",
        width = self.width,
        height = self.height,
        OnClick = {
            function()
                local mode = 'add'
                if self.value then
                    mode = 'edit'
                end
                self.windowType({
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
                -- SB.MakeWindowModal(TriggerDataTypeWindow.window, self.parent)
            end
        },
    }

    self.components = {
        self.btnDataType
    }
end

------------------
-- Window
------------------
SB.Include(Path.Join(SB_VIEW_TRIGGER_DIR, "abstract_trigger_element_window.lua"))

TriggerDataTypeWindow = AbstractTriggerElementWindow:extends{}

function TriggerDataTypeWindow:init(opts)
    self.dataType = opts.dataType
    self.dataTypeDef = SB.metaModel:GetDataType(self.dataType.type)
    AbstractTriggerElementWindow.init(self, opts)
end

function TriggerDataTypeWindow:GetValidElementTypes()
    return SB.CreateNameMapping({self.dataTypeDef})
end

function TriggerDataTypeWindow:GetWindowCaption()
    if self.mode == 'add' then
        return "New " .. self.dataTypeDef.humanName
    elseif self.mode == 'edit' then
        return "Edit " .. self.dataTypeDef.humanName
    end
end
