PlayersWindow = LCS.class{}

function PlayersWindow:init()
    self.teamsPanel = StackPanel:New {
        itemMargin = {0, 0, 0, 0},
        x = 1,
        y = 1,
        right = 1,
        autosize = true,
        resizeItems = false,
    }
    self:Populate()

    self.btnClose = Button:New {
        caption = 'Close',
        width = 100,
        right = 1,
        bottom = 1,
        height = SCEN_EDIT.conf.B_HEIGHT,
        OnClick = { function() self.window:Dispose() end }
    }
    self.btnAddPlayer = Button:New {
        caption='+ Team',
        width=120,
        x = 1,
        bottom = 1,
        height = SCEN_EDIT.conf.B_HEIGHT,
        OnClick={
            function()
                -- find new free id
                local teamIds = GetField(SCEN_EDIT.model.teams, "id")
                table.sort(teamIds)
                local id = 0
                for _, teamId in pairs(teamIds) do
                    if id ~= teamId then
                        break
                    end
                    id = id + 1
                end                
                SCEN_EDIT.model.teams[id] = {
                    id = id,
                    name = tostring(id) .. ": New team",
                    color = { r=math.random(), g=math.random(), b=math.random(), a=1},
                    allyTeam = 1,
                }
                self:Populate()
            end
        },
        backgroundColor = SCEN_EDIT.conf.BTN_ADD_COLOR,
    }
    self.window = Window:New {
        width = 370,
        height = math.min(800, math.max(400, 250 + #SCEN_EDIT.model.teams * 30)),
        minimumSize = {300,300},
        parent = screen0,
        caption = "Players",
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
            self.btnAddPlayer,
        }
    }
end

function PlayersWindow:Populate()
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
    for i, team in pairs(SCEN_EDIT.model.teams) do
        local stackTeamPanel = MakeComponentPanel(self.teamsPanel)
        local fontColor = SCEN_EDIT.glToFontColor(team.color)
        local aiPrefix = "(Player) "
        if team.ai then
            aiPrefix = "(AI) "
        end
        local lblTeam = Label:New {
            caption = aiPrefix .. fontColor .. "Team: " .. team.name .. "\b",
            x = 1,
            width = 150,
            parent = stackTeamPanel,
        }
        local btnEditTeam = Button:New {
            caption = 'Edit',
            x = 190,
            width = 80,
            parent = stackTeamPanel,
            OnClick = {
                function() 
                    local playerWindow = PlayerWindow(team)
                    table.insert(playerWindow.window.OnDispose, function() self:Populate() end)
                    playerWindow.window.x = self.window.x + self.window.width
                    playerWindow.window.y = self.window.y
                end
            },
        }
        local btnRemoveTeam = Button:New {
            caption = "",
            x = 280,
            width = SCEN_EDIT.conf.B_HEIGHT,
            height = SCEN_EDIT.conf.B_HEIGHT,
            parent = stackTeamPanel,
            padding = {0, 0, 0, 0},
            children = {
                Image:New { 
                    tooltip = "Remove team", 
                    file=SCEN_EDIT_IMG_DIR .. "list-remove.png", 
                    height = SCEN_EDIT.conf.B_HEIGHT, 
                    width = SCEN_EDIT.conf.B_HEIGHT, 
                    margin = {0, 0, 0, 0},
                },
            },
            OnClick = {
                function() 
                    SCEN_EDIT.model.teams[team.id] = nil
                    self:Populate()
                end
            }
        }
    end
end
