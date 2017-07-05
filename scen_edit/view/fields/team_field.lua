SB.Include(SB_VIEW_FIELDS_DIR .. "choice_field.lua")

TeamField = ChoiceField:extends{}

function TeamField:init(opts)
    local items = GetField(SB.model.teamManager:getAllTeams(), "name")
    local ids = GetField(SB.model.teamManager:getAllTeams(), "id")
    opts.items = items

    ChoiceField.init(self, opts)
end
