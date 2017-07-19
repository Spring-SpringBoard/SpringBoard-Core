SB.Include(SB_VIEW_FIELDS_DIR .. "field.lua")

TriggerDataTypeField = Field:extends{}

function TriggerDataTypeField:init(field)
    self:__SetDefault("width", 200)
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

    -- FIXME: AbstractTriggerElementWindow shouldn't use this information, but
    -- it has to right now
    if self.dataTypeDef then
        self.__isCoreDataType = not SB.metaModel:GetCustomDataType(self.dataType.type)
    end


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
