CustomWindow = AbstractTriggerElementWindow:extends{}

function CustomWindow:init(opts)
    opts.element = opts.condition
    self:super("init", opts)
end

function CustomWindow:GetValidElementTypes()
    return SCEN_EDIT.metaModel.functionTypesByOutput[self.dataType]
end

function CustomWindow:GetWindowCaption()
    if self.mode == 'add' then
        return "New expression of type " .. self.dataType
    elseif self.mode == 'edit' then
        return "Edit expression of type " .. self.dataType
    end
end

function CustomWindow:AddParent()
    table.insert(self.parentObj, self.element)
end
