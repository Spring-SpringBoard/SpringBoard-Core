SB.Include(Path.Join(SB_VIEW_TRIGGER_DIR, "abstract_trigger_element_window.lua"))

ConditionWindow = AbstractTriggerElementWindow:extends{}

function ConditionWindow:init(opts)
    opts.element = opts.condition
    AbstractTriggerElementWindow.init(self, opts)
end

function ConditionWindow:GetValidElementTypes()
    return SB.metaModel.functionTypesByOutput["bool"]
end

function ConditionWindow:GetWindowCaption()
    if self.mode == 'add' then
        return "New condition for - " .. self.trigger.name
    elseif self.mode == 'edit' then
        return "Edit condition for trigger " .. self.trigger.name
    end
end
