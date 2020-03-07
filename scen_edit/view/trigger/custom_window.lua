SB.Include(Path.Join(SB.DIRS.SRC, 'view/trigger/abstract_trigger_element_window.lua'))

CustomWindow = AbstractTriggerElementWindow:extends{}

function CustomWindow:init(opts)
    opts.element = opts.condition
    self.dataType = opts.dataType
    AbstractTriggerElementWindow.init(self, opts)
end

function CustomWindow:GetValidElementTypes()
    return SB.metaModel.functionTypesByOutput[self.dataType.type]
end

function CustomWindow:GetWindowCaption()
    if self.mode == 'add' then
        return "New expression of type " .. self.dataType.type
    elseif self.mode == 'edit' then
        return "Edit expression of type " .. self.dataType.type
    end
end
