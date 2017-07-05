SB.Include(Path.Join(SB_VIEW_TRIGGER_DIR, "abstract_trigger_element_window.lua"))

ActionWindow = AbstractTriggerElementWindow:extends{}

function ActionWindow:init(opts)
    opts.element = opts.action
    AbstractTriggerElementWindow.init(self, opts)
end

function ActionWindow:GetValidElementTypes()
    return SB.metaModel.actionTypes
end

function ActionWindow:GetWindowCaption()
    if self.mode == 'add' then
        return "New action for - " .. self.trigger.name
    elseif self.mode == 'edit' then
        return "Edit action for trigger " .. self.trigger.name
    end
end
