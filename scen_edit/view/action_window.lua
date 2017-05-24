ActionWindow = AbstractTriggerElementWindow:extends{}

function ActionWindow:init(opts)
    opts.element = opts.action
    self:super("init", opts)
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

function ActionWindow:AddParent()
    table.insert(self.trigger.actions, self.element)
end
