SB.Include(Path.Join(SB_VIEW_DIR, "editor.lua"))

NewProjectDialog = Editor:extends{}

function NewProjectDialog:init()
    self:super("init")

    self.initializing = true

    local btnOK = Button:New {
        caption = 'OK',
        width = '40%',
        x = 1,
        bottom = 1,
        height = SB.conf.B_HEIGHT,
        classname = "option_button",
        OnClick = {
            function()
                -- self:LoadEmptyMap()
                self:LoadExistingMap()
            end
        }
    }
    local btnCancel = Button:New {
        caption = 'Cancel',
        width = '40%',
        x = '50%',
        bottom = 1,
        height = SB.conf.B_HEIGHT,
        classname = "negative_button",
        OnClick = {
            function()
                self.window:Dispose()
            end
        }
    }

    self:AddField(ChoiceField({
        name = "mapName",
        title = "Map:",
        items = VFS.GetMaps(),
        width = 300,
    }))

    -- self:AddField(GroupField({
    --     NumericField({
    --         name = "sizeX",
    --         title = "Size X:",
    --         width = 140,
    --         minValue = 1,
    --         value = 5,
    --         maxValue = 32,
    --     }),
    --     NumericField({
    --         name = "sizeZ",
    --         title = "Size Z:",
    --         width = 140,
    --         minValue = 1,
    --         value = 5,
    --         maxValue = 32,
    --     })
    -- }))

    local children = {
        btnOK,
        btnCancel,
        ScrollPanel:New {
            x = 0,
            y = 0,
            bottom = 30,
            right = 0,
            borderColor = {0,0,0,0},
            horizontalScrollbar = false,
            children = { self.stackPanel },
        },
    }

    self:Finalize(children, {
        notMainWindow = true,
        noCloseButton = true,
        width = 500,
        height = 200,
    })
end

-- Generates teams, allyteams, players and AI for a new map
local function GenerateEmptyMapParticipants()
    return {
        players = {
            {
                name = 'Player',
                team = 0,
                isFromDemo = 0,
                spectator = 0,
                rank = 0,
                host = 1,
            },
        },
        ais = {
            {
                name = 'AI',
                team = 1,
                isFromDemo = 0,
                shortName = "NullAI",
                version = "",
                host = 0,
            },
        },
        teams = {
            {
                RGBColor = "0.2 0.9 0.7",
                allyTeam = 0,
                teamLeader = 0
            },
            {
                RGBColor = "0.9 0.5 0",
                allyTeam = 1,
                teamLeader = 0
            }
        },
        allyTeams = {
            {
                numAllies = 1,
            },
            {
                numAllies = 1,
            },
        }
    }
end

function NewProjectDialog:LoadEmptyMap()
    local participants = GenerateEmptyMapParticipants()
    local scriptTxt = StartScript.GenerateScriptTxt({
        game = {
            name = Game.gameName,
            version = Game.gameVersion,
        },
        mapName = "FlatTemplate",
        teams = participants.teams,
        players = participants.players,
        ais = participants.ais,
        allyTeams = participants.allyTeams,
        mapOptions = {
            sizeX = self.fields["sizeX"].value,
            sizeZ = self.fields["sizeZ"].value,
        },
        modOptions = SB.GetPersistantModOptions(),
    })
    Spring.Echo(scriptTxt)
    Spring.Reload(scriptTxt)
end

function NewProjectDialog:LoadExistingMap()
    local participants = GenerateEmptyMapParticipants()
    local scriptTxt = StartScript.GenerateScriptTxt({
        game = {
            name = Game.gameName,
            version = Game.gameVersion,
        },
        mapName = self.fields["mapName"].value,
        teams = participants.teams,
        players = participants.players,
        ais = participants.ais,
        allyTeams = participants.allyTeams,
        modOptions = SB.GetPersistantModOptions(),
    })
    Spring.Echo(scriptTxt)
    Spring.Reload(scriptTxt)
end
