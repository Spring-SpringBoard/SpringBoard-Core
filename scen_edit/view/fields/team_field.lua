SB.Include(Path.Join(SB.DIRS.SRC, 'view/fields/choice_field.lua'))

--- TeamField module.

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
    local teamIDs = {}
    local teamCaptions = {}

    local sortedTeams = Table.SortByAttr(SB.model.teamManager:getAllTeams(), "id")
    for _, team in pairs(sortedTeams) do
        local teamCaption = team.name
        if team.color then
            teamCaption = SB.glToFontColor(team.color) .. teamCaption .. "\b"
        end

        teamCaption = teamCaption .. " (ID: " .. tonumber(team.id) .. ")"
        table.insert(teamCaptions, teamCaption)
        table.insert(teamIDs, team.id)
    end

    opts.items = teamIDs
    opts.captions = teamCaptions

    ChoiceField.init(self, opts)
end
