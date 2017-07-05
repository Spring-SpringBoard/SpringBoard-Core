SB.Include(SB_VIEW_FIELDS_DIR .. "choice_field.lua")

TriggerField = ChoiceField:extends{}

function TriggerField:init(opts)
    local triggerNames = {}
    local triggerIDs = {}

    for id, trigger in pairs(SB.model.triggerManager:getAllTriggers()) do
        table.insert(triggerNames, trigger.name)
        table.insert(triggerIDs, trigger.id)
    end

    opts.title = "Triggers:"
    opts.captions = triggerNames
    opts.items = triggerIDs

    ChoiceField.init(self, opts)
end
