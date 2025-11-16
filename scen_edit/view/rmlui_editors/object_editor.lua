--- RmlUi Object Editor
--- 100% programmatic - no RML file needed!

RmlUiObjectEditor = RmlUiEditorBase:extends{}

function RmlUiObjectEditor:init()
    self:super("init")
    self.editorTitle = "Object Editor"
    self.currentObject = nil

    -- TODO when implementing: Add fields programmatically
    -- self:AddField(NumericField({name="x", title="X Position"}))
    -- self:AddField(NumericField({name="y", title="Y Position"}))
    -- self:AddField(NumericField({name="z", title="Z Position"}))
end

function RmlUiObjectEditor:SetObject(objectID)
    self.currentObject = objectID
    Log.Notice("Set object: " .. tostring(objectID) .. " (not implemented)")
end

function RmlUiObjectEditor:RefreshProperties()
    Log.Notice("Refresh properties (not implemented)")
end
