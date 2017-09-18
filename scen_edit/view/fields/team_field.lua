--- TeamField module.
SB.Include(SB_VIEW_FIELDS_DIR .. "choice_field.lua")

--- TeamField class.
-- @type TeamField
TeamField = ChoiceField:extends{}

--- TeamField constructor.
-- @function TeamField()
-- @see choice_field.ChoiceField
-- @tparam table opts Table
-- @tparam string opts.title Title.
-- @usage
-- TeamField({
--     name = "myArrayField",
--     title = "Teams",
-- })
function TeamField:init(opts)
    local items = GetField(SB.model.teamManager:getAllTeams(), "name")
    local ids = GetField(SB.model.teamManager:getAllTeams(), "id")
    opts.items = items

    ChoiceField.init(self, opts)
end
