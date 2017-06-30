SB.Include(Path.Join(SB_VIEW_DIR, "editor.lua"))

ExampleEditor = Editor:extends{}
Editor.Register({
    name = "exampleEditor",
    editor = ExampleEditor,
    tab = "Example",
    caption = "Example",
    tooltip = "Example editor",
    -- TODO: Fix image/path for extensions
    image = SB_IMG_DIR .. "globe.png",
})

function ExampleEditor:init()
    self:super("init")

    self.initializing = true

    self:AddField(NumericField({
        name = "example",
        title = "Example:",
        tooltip = "Example value tooltip.",
        width = 140,
        minValue = -10,
        maxValue = 5,
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

    self:Finalize(children)
    self.initializing = false
end
