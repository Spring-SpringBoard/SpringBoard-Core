SB.Include(Path.Join(SB.DIRS.SRC, 'view/trigger/abstract_trigger_element_window.lua'))

OrderWindow = AbstractTriggerElementWindow:extends{}

function OrderWindow:GetValidElementTypes()
    return SB.metaModel.orderTypes
end

function OrderWindow:GetWindowCaption()
    if self.mode == 'add' then
        return "New order "
    elseif self.mode == 'edit' then
        return "Edit order "
    end
end
