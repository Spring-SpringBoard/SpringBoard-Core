SB.Include(Path.Join(SB.DIRS.SRC, 'view/editor.lua'))

PlayersWindow = Editor:extends{}
PlayersWindow:Register({
    name = "playersWindow",
    tab = "Misc",
    caption = "Teams",
    tooltip = "Edit teams",
    image = Path.Join(SB.DIRS.IMG, 'person.png'),
    order = 1,
})

function PlayersWindow:init()
    self:super("init")

    -- The RmlUi teams list is rendered into this container by
    -- RefreshRmlUiContent(); the Chili path uses self.teamsPanel below.
    self.rmlUiContentId = "teams-list"

    self.teamsPanel = StackPanel:New {
        itemMargin = {0, 0, 0, 0},
        x = 1,
        y = 1,
        right = 1,
        autosize = true,
        resizeItems = false,
    }
    SB.model.teamManager:addListener(self)
    self:Populate()

    self.btnAddPlayer = ActionButton({
        x = 0,
        y = 0,
        tooltip = "Add team",
        children = {
            TabbedPanelImage({ file = Path.Join(SB.DIRS.IMG, 'team-add.png') }),
            TabbedPanelLabel({ caption = "Add" }),
        },
        OnClick = {
            function()
                local name = "New team: " .. tostring(#SB.model.teamManager:getAllTeams())
                local color = { r=math.random(), g=math.random(), b=math.random(), a=1}
                local allyTeam = 1
                local side = Spring.GetSideData(1)
                local cmd = AddTeamCommand(name, color, allyTeam, side)
                SB.commandManager:execute(cmd)
            end
        },
    })
    self:AddDefaultKeybinding({
        self.btnAddPlayer
    })

    self:Finalize({
        actionButtons = {
            self.btnAddPlayer,
        },
    })
end

local function TeamPrefix(team)
    if team.gaia then
        return "(Gaia)"
    elseif team.ai then
        return "(AI)"
    end
    return "(Player)"
end

local function EscapeRml(text)
    text = tostring(text or "")
    return (text:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"))
end

-- RmlUi renders the teams list into the editor's custom content container.
-- The Chili path below builds a StackPanel instead, which has no RmlUi
-- equivalent, so the list was simply missing in RmlUi mode.
function PlayersWindow:RefreshRmlUiContent()
    local document = SB.view.mainDocument
    local container = document and document:GetElementById(self.rmlUiContentId)
    if not container then
        return
    end

    local html = '<div class="team-list-header">Teams</div>'
    local teams = {}
    for _, team in pairs(SB.model.teamManager:getAllTeams()) do
        table.insert(teams, team)
    end
    table.sort(teams, function(a, b) return tonumber(a.id) < tonumber(b.id) end)

    for _, team in ipairs(teams) do
        local color = team.color or {r = 1, g = 1, b = 1}
        local swatch = string.format("#%02X%02X%02X",
            math.floor((color.r or 1) * 255 + 0.5),
            math.floor((color.g or 1) * 255 + 0.5),
            math.floor((color.b or 1) * 255 + 0.5))
        html = html .. string.format('<div class="team-row" id="team-row-%s">', tostring(team.id))
        html = html .. string.format('<div class="team-swatch" style="background-color: %s;"></div>', swatch)
        html = html .. string.format('<span class="team-name">%s Team: %s</span>',
            EscapeRml(TeamPrefix(team)), EscapeRml(team.name))
        if not team.gaia then
            html = html .. string.format('<button class="team-edit" id="team-edit-%s">Edit</button>', tostring(team.id))
            html = html .. string.format('<button class="team-remove" id="team-remove-%s">x</button>', tostring(team.id))
        end
        html = html .. '</div>'
    end
    container.inner_rml = html

    for _, team in ipairs(teams) do
        if not team.gaia then
            self:_BindTeamRowEvents(document, team)
        end
    end
end

function PlayersWindow:_BindTeamRowEvents(document, team)
    local teamID = team.id
    local btnEdit = document:GetElementById("team-edit-" .. tostring(teamID))
    if btnEdit then
        btnEdit:AddEventListener("click", function()
            self:_OnEditTeam(team)
        end)
    end
    local btnRemove = document:GetElementById("team-remove-" .. tostring(teamID))
    if btnRemove then
        btnRemove:AddEventListener("click", function()
            self:_OnRemoveTeam(teamID)
        end)
    end
end

-- Deferred: these rebuild the list DOM, which must not happen while RmlUi is
-- still dispatching the click that triggered them.
function PlayersWindow:_OnEditTeam(team)
    SB.delay(function()
        PlayerWindow(team)
    end)
end

function PlayersWindow:_OnRemoveTeam(teamID)
    SB.delay(function()
        SB.commandManager:execute(RemoveTeamCommand(teamID))
    end)
end

function PlayersWindow:Populate()
    if SB.useRmlUi then
        self:RefreshRmlUiContent()
        return
    end
    self.teamsPanel:ClearChildren()
    --titles
    local titlesPanel = MakeComponentPanel(self.teamsPanel)
    local lblTeams = Label:New {
        caption = "Teams",
        x = 1,
        width = 150,
        parent = titlesPanel,
    }
    --teams
    for _, team in pairs(SB.model.teamManager:getAllTeams()) do
        local stackTeamPanel = MakeComponentPanel(self.teamsPanel)
        local fontColor = SB.glToFontColor(team.color or {r=1, g=1, b=1})
        local aiPrefix = "(Player) "
        if team.gaia then
            aiPrefix = "(Gaia)"
        elseif team.ai then
            aiPrefix = "(AI) "
        end
        local lblTeam = Label:New {
            caption = aiPrefix .. fontColor .. "Team: " .. team.name .. "\b",
            x = 1,
            width = 150,
            parent = stackTeamPanel,
        }
        if not team.gaia then
            local btnEditTeam = Button:New {
                caption = 'Edit',
                x = 190,
                width = 80,
                height = SB.conf.B_HEIGHT,
                parent = stackTeamPanel,
                OnClick = {
                    function()
                        local playerWindow = PlayerWindow(team)
                        playerWindow.window.x = self.window.x + self.window.width
                        playerWindow.window.y = self.window.y
                    end
                },
            }
            local btnRemoveTeam = Button:New {
                caption = "",
                x = 280,
                width = SB.conf.B_HEIGHT,
                height = SB.conf.B_HEIGHT,
                parent = stackTeamPanel,
                padding = {2, 2, 2, 2},
                tooltip = "Remove team",
                classname = "negative_button",
                children = {
                    Image:New {
                        file = Path.Join(SB.DIRS.IMG, 'cancel.png'),
                        height = "100%",
                        width = "100%",
                    },
                },
                OnClick = {
                    function()
                        local cmd = RemoveTeamCommand(team.id)
                        SB.commandManager:execute(cmd)
                    end
                }
            }
        end
    end
end

function PlayersWindow:onTeamAdded(teamID)
    self:Populate()
end

function PlayersWindow:onTeamRemoved(teamID)
    self:Populate()
end

function PlayersWindow:onTeamChange(teamID, team)
    self:Populate()
end
