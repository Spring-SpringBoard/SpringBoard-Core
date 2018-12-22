SB.Include(Path.Join(SB_VIEW_DIR, "editor.lua"))

NewProjectDialog = Editor:extends{}

function NewProjectDialog:init()
    self:super("init")

    local items = VFS.GetMaps()
    table.insert(items, 1, "SB_Blank_Map")
    local captions = Table.DeepCopy(items)
    captions[1] = "Blank"
    self:AddField(ChoiceField({
        name = "mapName",
        title = "Map:",
        items = items,
        captions = captions,
        width = 300,
    }))

    self:AddField(GroupField({
        NumericField({
            name = "sizeX",
            title = "Size X:",
            width = 140,
            minValue = 1,
            value = 5,
            maxValue = 32,
        }),
        NumericField({
            name = "sizeZ",
            title = "Size Z:",
            width = 140,
            minValue = 1,
            value = 5,
            maxValue = 32,
        })
    }))

    local children = {
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
        buttons = { "ok", "cancel" },
        width = 400,
        height = 200,
    })
end

function NewProjectDialog:ConfirmDialog()
    if self.fields.mapName.value == "SB_Blank_Map" then
        if self.fields.sizeX.value > 0 and self.fields.sizeZ.value > 0 then
            self:LoadEmptyMap()
        end
    else
        self:LoadExistingMap()
    end
end

function NewProjectDialog:OnFieldChange(name, value)
    if name == "mapName" then
        if value == "SB_Blank_Map" then
            self:SetInvisibleFields()
        else
            self:SetInvisibleFields("sizeX", "sizeZ")
        end
    end
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
    local sizeX, sizeZ = self.fields.sizeX.value, self.fields.sizeZ.value
    local participants = GenerateEmptyMapParticipants()

    local script = {
        game = {
            name = Game.gameName,
            version = Game.gameVersion,
        },
        mapSeed = 1,
        mapName = "SB_Blank_Template_" .. tostring(sizeX) .. "x" .. tostring(sizeZ),
        teams = participants.teams,
        players = participants.players,
        ais = participants.ais,
        allyTeams = participants.allyTeams,
        mapOptions = {
            new_map_x = sizeX,
            new_map_z = sizeZ,
        },
        modOptions = SB.GetPersistantModOptions(),
    }

    local scriptTxt = StartScript.GenerateScriptTxt(script)
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
        mapName = self.fields.mapName.value,
        teams = participants.teams,
        players = participants.players,
        ais = participants.ais,
        allyTeams = participants.allyTeams,
        modOptions = SB.GetPersistantModOptions(),
    })
    Spring.Echo(scriptTxt)
    Spring.Reload(scriptTxt)
end
