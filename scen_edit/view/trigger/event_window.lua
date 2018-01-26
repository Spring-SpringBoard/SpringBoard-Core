SB.Include(Path.Join(SB_VIEW_TRIGGER_DIR, "abstract_trigger_element_window.lua"))

EventWindow = AbstractTriggerElementWindow:extends{}

function EventWindow:init(opts)
    self.tbInfo = TextBox:New {
        text = "",
        x = 0,
        right = 0,
        y = 0,
        autosize = true,
        padding = {0, 0, 0, 0},
    }

    opts.element = opts.event
    opts.height = 200
    AbstractTriggerElementWindow.init(self, opts)
end

function EventWindow:GetValidElementTypes()
    return SB.metaModel.eventTypes
end

function EventWindow:GetWindowCaption()
    if self.mode == 'add' then
        return "New event for - " .. self.trigger.name
    elseif self.mode == 'edit' then
        return "Edit event for trigger " .. self.trigger.name
    end
end

function EventWindow:OnExprTypeChange(exprType)
    local txtInfo = ""
    for i, param in pairs(exprType.param) do
        if i == 1 then
            txtInfo = "Params: "
        else
            txtInfo = txtInfo .. ", "
        end
        txtInfo = txtInfo .. param.name
    end
    self.tbInfo:SetText(txtInfo)
    self.elementPanel:AddChild(self.tbInfo)
end
