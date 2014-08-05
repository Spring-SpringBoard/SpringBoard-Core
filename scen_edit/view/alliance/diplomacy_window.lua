DiplomacyWindow = LCS.class{}

function DiplomacyWindow:init(trigger)
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
    for id, team in pairs(SCEN_EDIT.model.teamManager:getAllTeams()) do        
        local fontColor = SCEN_EDIT.glToFontColor(team.color)
        local lblTeam = Label:New {
            caption = fontColor .. id .. "\b",
            x = 160 + i * 40,
            width = 30,
            parent = titlesPanel,
        }
        i = i + 1
    end

    --teams
    for _, team in pairs(SCEN_EDIT.model.teamManager:getAllTeams()) do
        local stackTeamPanel = MakeComponentPanel(self.teamsPanel)
        local fontColor = SCEN_EDIT.glToFontColor(team.color)
        local lblTeam = Label:New {
            caption = fontColor .. "Team: " .. team.name .. "\b",
            x = 1,
            width = 150,
            parent = stackTeamPanel,
        }
        for _, team2 in pairs(SCEN_EDIT.model.teamManager:getAllTeams()) do
            if team1.id ~= team2.id then
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
                            SCEN_EDIT.commandManager:execute(cmd)
                        end
                    }
                }
            end
        end
        --[[
        local cmbAlliance = ComboBox:New {
            x = 160,
            width = 110,
            height = SCEN_EDIT.conf.B_HEIGHT,
            parent = stackTeamPanel,
            items = {0, 1, 2, 3, 4, 5, 6, 7, 8, 9},
        }
        cmbAlliance:Select(team.allyTeam + 1)
        cmbAlliance.OnSelect = {
            function(obj, itemIdx, selected)
                if selected and itemIdx > 0 then
                    local newAllyTeamId = cmbAlliance.items[itemIdx]
                    if newAllyTeamId ~= team.allyTeam then
                        local cmd = ChangeAllyTeamCommand(team.id, newAllyTeamId)
                        SCEN_EDIT.commandManager:execute(cmd)
                        -- TODO: should be updated in a listener instead
                        team.allyTeam = newAllyTeamId
                    end
                end
            end
        }
        --]]
    end

    self.btnClose = Button:New {
        caption='Close',
        width = 100,
        right = 1,
        bottom = 1,
        height = SCEN_EDIT.conf.B_HEIGHT,
        OnClick = { function() self.window:Dispose() end }
    }
    self.window = Window:New {
        width = math.min(800, math.max(400, 250 + #SCEN_EDIT.model.teamManager:getAllTeams() * 30)),
        height = math.min(800, math.max(400, 250 + #SCEN_EDIT.model.teamManager:getAllTeams() * 30)),
        minimumSize = {300,300},
        parent = screen0,
        caption = "Alliances",
        x = 500,
        y = 200,
        children = {
            ScrollPanel:New {
                x = 1,
                y = 15,
                right = 5,
                bottom = SCEN_EDIT.conf.C_HEIGHT * 2,
                children = { 
                    self.teamsPanel
                },
            },
            self.btnClose,
        }
    }
end
