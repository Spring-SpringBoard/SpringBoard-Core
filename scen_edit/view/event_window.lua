EventWindow = AbstractTriggerElementWindow:extends{}

function EventWindow:init(opts)
    opts.element = opts.event
    self:super("init", opts)
    self.tbInfo = TextBox:New {
        text = "",
        x = 1,
        right = 1,
        y = "80%",
        autosize = true,
        padding = {0, 0, 0, 0},
    }
end

function EventWindow:GetValidElementTypes()
    return SCEN_EDIT.metaModel.eventTypes
end

function EventWindow:GetWindowCaption()
    if self.mode == 'add' then
        return "New event for - " .. self.trigger.name
    elseif self.mode == 'edit' then
        return "Edit event for trigger " .. self.trigger.name
    end
end

function EventWindow:UpdateInfo()
    local txtInfo = ""
    for i, param in pairs(self.eventType.param) do
        if i == 1 then
            txtInfo = "Params: "
        else
            txtInfo = txtInfo .. ", "
        end
        txtInfo = txtInfo .. param.name
    end
    self.tbInfo:SetText(txtInfo)
end

function EventWindow:AddParent()
    table.insert(self.trigger.events, self.element)
end
