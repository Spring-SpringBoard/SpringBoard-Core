--- RmlUi Texture Editor
--- 100% programmatic - no RML file needed!

RmlUiTextureEditor = RmlUiEditorBase:extends{}

function RmlUiTextureEditor:init()
    self:super("init")
    self.editorTitle = "Texture Editor"
    self.currentTool = "paint"
    self.selectedTexture = 0

    -- TODO when implementing: Add fields programmatically
    -- self:AddField(ChoiceField({name="tool", title="Tool", items={"Paint", "Erase", "Fill"}}))
    -- self:AddField(NumericField({name="brushSize", title="Brush Size", min=1, max=100}))
    -- self:AddField(AssetField({name="texture", title="Texture"}))
end

function RmlUiTextureEditor:SetTool(tool)
    self.currentTool = tool
    Log.Notice("Texture tool: " .. tool)
end

function RmlUiTextureEditor:Update()
    -- Stub
end
