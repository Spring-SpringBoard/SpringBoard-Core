SB.Include(Path.Join(SB_VIEW_DIR, "editor.lua"))

NewTextureDialog = Editor:extends{}

function NewTextureDialog:init(opts)
    self:super("init")

    self.name = opts.name
    self.engineName = opts.engineName
    local sizeX = opts.sizeX
    local sizeY = opts.sizeY
    local color = opts.color

    self:AddField(ChoiceField({
        name = "source",
        title = "Source:",
        items = {"New", "Existing"},
        width = 300,
    }))

    self:AddField(GroupField({
        NumericField({
            name = "sizeX",
            title = "Size X:",
            width = 140,
            minValue = 1,
            value = sizeX or 128,
        }),
        NumericField({
            name = "sizeY",
            title = "Size Y:",
            width = 140,
            minValue = 1,
            value = sizeY or 128,
        })
    }))

    self:AddField(ColorField({
        name = 'color',
        title = 'Color:',
        width = 100,
        value = color,
    }))

    self:AddField(AssetField({
        name = "texture",
        title = "Texture:",
    }))

    local children = {
        ScrollPanel:New {
            x = 0,
            y = 0,
            bottom = 30,
            right = 0,
            borderColor = {0, 0, 0, 0},
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

    self:__RefreshVisible()
end

function NewTextureDialog:OnFieldChange(name, value)
    if name == "source" then
        self:__RefreshVisible()
    end
end

function NewTextureDialog:__RefreshVisible()
    if self.fields["source"].value == "New" then
        self:SetInvisibleFields("texture")
    else
        self:SetInvisibleFields("color")
        -- self:SetInvisibleFields("sizeX", "sizeY", "color")
    end
end