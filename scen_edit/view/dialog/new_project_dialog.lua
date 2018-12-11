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

function NewProjectDialog:LoadEmptyMap()
    local scriptTxt = StartScript.GenerateScriptTxt({
        game = {
            name = Game.gameName,
            version = Game.gameVersion,
        },
        mapName = "FlatTemplate",
        teams = {},
        players = {},
        ais = {},
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
    local scriptTxt = StartScript.GenerateScriptTxt({
        game = {
            name = Game.gameName,
            version = Game.gameVersion,
        },
        mapName = self.fields["mapName"].value,
        modOptions = SB.GetPersistantModOptions(),
        teams = {},
        players = {},
        ais = {},
    })
    Spring.Echo(scriptTxt)
    Spring.Reload(scriptTxt)
end
