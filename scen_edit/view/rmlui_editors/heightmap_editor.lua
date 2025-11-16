--- RmlUi Heightmap Editor
--- 100% programmatic - no RML file needed!

RmlUiHeightmapEditor = RmlUiEditorBase:extends{}

function RmlUiHeightmapEditor:init()
    self:super("init")
    self.editorTitle = "Heightmap Editor"
    self.currentTool = "raise"

    -- TODO when implementing: Add fields programmatically
    -- self:AddField(ChoiceField({name="tool", title="Tool", items={"Raise", "Lower", "Smooth", "Level"}}))
    -- self:AddField(NumericField({name="brushSize", title="Brush Size", min=1, max=100}))
    -- self:AddField(NumericField({name="strength", title="Strength", min=0, max=1, step=0.01}))
end

function RmlUiHeightmapEditor:SetTool(tool)
    self.currentTool = tool
    Log.Notice("Heightmap tool: " .. tool)
end

function RmlUiHeightmapEditor:Update()
    -- Stub
end
