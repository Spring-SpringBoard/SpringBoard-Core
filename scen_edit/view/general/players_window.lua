SB.Include(SB_VIEW_DIR .. "editor.lua")
PlayersWindow = Editor:extends{}

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
    SB.model.teamManager:addListener(self)
    self:Populate()

    self.btnAddPlayer = TabbedPanelButton({
        x = 0,
        y = 0,
        tooltip = "Add team",
        children = {
            TabbedPanelImage({ file = SB_IMG_DIR .. "team-add.png" }),
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

    local children = {
        ScrollPanel:New {
            x = 0,
            y = 80,
            bottom = 30,
            right = 0,
            borderColor = {0,0,0,0},
            horizontalScrollbar = false,
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
    for _, team in pairs(SB.model.teamManager:getAllTeams()) do
        local stackTeamPanel = MakeComponentPanel(self.teamsPanel)
        local fontColor = SB.glToFontColor(team.color)
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
                        file = SB_IMG_DIR .. "cancel.png",
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
