SB.Include(Path.Join(SB.DIRS.SRC, 'view/fields/field.lua'))

TriggerDataTypeField = Field:extends{}

function TriggerDataTypeField:Update(source)
    self.btnDataType:SetCaption(self:_GetCaption())
end

function TriggerDataTypeField:init(field)
    self:__SetDefault("width", 200)
    self.windowType = TriggerDataTypeWindow

    Field.init(self, field)

    self.btnDataType = Button:New {
        caption = self:_GetCaption(),
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

function TriggerDataTypeField:_GetCaption()
    --return SB.humanExpression(self.value, "value", self.dataType)
    if self.value then
        local customDataType = SB.metaModel:GetCustomDataType(self.dataType.type)
        if customDataType then
            local result = SB.humanExpression({
                type = "const",
                value = self.value,
            }, "value", self.dataType.type)
            return customDataType.humanName .. "(".. result .. ")"
        else
            local result = SB.humanExpression(self.value, "value", self.dataType.type)
            return result
        end
    else
        local dataTypeDef = SB.metaModel:GetDataType(self.dataType.type)
        return String.Capitalize(dataTypeDef.humanName)
    end
end

------------------
-- Window
------------------
SB.Include(Path.Join(SB.DIRS.SRC, 'view/trigger/abstract_trigger_element_window.lua'))

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
    return Table.CreateNameMapping({self.dataTypeDef})
end

function TriggerDataTypeWindow:GetWindowCaption()
    if self.mode == 'add' then
        return "New " .. self.dataTypeDef.humanName
    elseif self.mode == 'edit' then
        return "Edit " .. self.dataTypeDef.humanName
    end
end
