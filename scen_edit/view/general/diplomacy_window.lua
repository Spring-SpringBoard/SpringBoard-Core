SB.Include(SB_VIEW_DIR .. "editor.lua")
DiplomacyWindow = Editor:extends{}

function DiplomacyWindow:init(trigger)
    self:super("init")

    self.teamsPanel = StackPanel:New {
        itemMargin = {0, 0, 0, 0},
        x = 1,
        y = 1,
        right = 1,
        autosize = true,
        resizeItems = false,
    }
    --titles
    local titlesPanel = MakeComponentPanel(self.teamsPanel)
    local lblTeams = Label:New {
        caption = "Teams",
        x = 1,
        width = 150,
        parent = titlesPanel,
    }
    local i = 1
    for id, team in pairs(SB.model.teamManager:getAllTeams()) do
        local fontColor = SB.glToFontColor(team.color)
        local lblTeam = Label:New {
            caption = fontColor .. id .. "\b",
            x = 160 + i * 40,
            width = 30,
            parent = titlesPanel,
        }
        i = i + 1
    end

    --teams
    for _, team in pairs(SB.model.teamManager:getAllTeams()) do
        local stackTeamPanel = MakeComponentPanel(self.teamsPanel)
        local fontColor = SB.glToFontColor(team.color)
        local lblTeam = Label:New {
            caption = fontColor .. "Team: " .. team.name .. "\b",
            x = 1,
            width = 150,
            parent = stackTeamPanel,
        }
        local j = 1
        for _, team2 in pairs(SB.model.teamManager:getAllTeams()) do
            if team.id ~= team2.id then
                self.cbSpecialUnit = Checkbox:New {
                    caption = '',
                    x = 160 + j * 40,
                    width = 30,
                    checked = Spring.AreTeamsAllied(team.id, team2.id),
                    boxalign = 'left',
                    parent = stackTeamPanel,
                    OnChange = {
                        function(cbToggled, checked)
                            local cmd = SetAllyCommand(team.allyTeam, team2.allyTeam, checked)
                            SB.commandManager:execute(cmd)
                        end
                    }
                }
            end
            j = j + 1
        end
        --[[
        local cmbAlliance = ComboBox:New {
            x = 160,
            width = 110,
            height = SB.conf.B_HEIGHT,
            parent = stackTeamPanel,
            items = {0, 1, 2, 3, 4, 5, 6, 7, 8, 9},
        }
        cmbAlliance:Select(team.allyTeam + 1)
        cmbAlliance.OnSelect = {
            function(obj, itemIdx, selected)
                if selected and itemIdx > 0 then
                    local newAllyTeamID = cmbAlliance.items[itemIdx]
                    if newAllyTeamID ~= team.allyTeam then
                        local cmd = ChangeAllyTeamCommand(team.id, newAllyTeamID)
                        SB.commandManager:execute(cmd)
                        -- TODO: should be updated in a listener instead
                        team.allyTeam = newAllyTeamID
                    end
                end
            end
        }
        --]]
    end

    local children = {
        ScrollPanel:New {
            x = 0,
            y = 0,
            bottom = 30,
            right = 0,
            borderColor = {0,0,0,0},
            horizontalScrollbar = false,
            children = {
                self.teamsPanel
            },
        },
    }
    self:Finalize(children)
end
