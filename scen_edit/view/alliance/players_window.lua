SCEN_EDIT.Include(SCEN_EDIT_VIEW_DIR .. "editor_view.lua")
PlayersWindow = EditorView:extends{}

function PlayersWindow:init()
    self:super("init")

    self.teamsPanel = StackPanel:New {
        itemMargin = {0, 0, 0, 0},
        x = 1,
        y = 1,
        right = 1,
        autosize = true,
        resizeItems = false,
    }
    SCEN_EDIT.model.teamManager:addListener(self)
    self:Populate()

    self.btnAddPlayer = Button:New {
        caption='+ Team',
        width=120,
        x = 1,
        bottom = 1,
        height = SCEN_EDIT.conf.B_HEIGHT,
        OnClick={
            function()
                local name = "New team: " .. tostring(#SCEN_EDIT.model.teamManager:getAllTeams())
                local color = { r=math.random(), g=math.random(), b=math.random(), a=1}
                local allyTeam = 1
                local side = Spring.GetSideData(1)
                local cmd = AddTeamCommand(name, color, allyTeam, side)
                SCEN_EDIT.commandManager:execute(cmd)
            end
        },
        backgroundColor = SCEN_EDIT.conf.BTN_ADD_COLOR,
    }
    local children = {
        ScrollPanel:New {
            x = 1,
            y = 15,
            right = 5,
            bottom = SCEN_EDIT.conf.C_HEIGHT * 2,
            children = {
                self.teamsPanel
            },
        },
        self.btnAddPlayer,
    }
    self:Finalize(children)
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
    for _, team in pairs(SCEN_EDIT.model.teamManager:getAllTeams()) do
        local stackTeamPanel = MakeComponentPanel(self.teamsPanel)
        local fontColor = SCEN_EDIT.glToFontColor(team.color)
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
                height = SCEN_EDIT.conf.B_HEIGHT,
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
                        local cmd = RemoveTeamCommand(team.id)
                        SCEN_EDIT.commandManager:execute(cmd)
                    end
                }
            }
        end
    end
end

function PlayersWindow:onTeamAdded(teamId)
    self:Populate()
end

function PlayersWindow:onTeamRemoved(teamId)
    self:Populate()
end

function PlayersWindow:onTeamChange(teamId, team)
    self:Populate()
end
