--- RmlUi Trigger Editor
--- 100% programmatic - no RML file needed!

RmlUiTriggerEditor = RmlUiEditorBase:extends{}

function RmlUiTriggerEditor:init()
    self:super("init")
    self.editorTitle = "Trigger Editor"
    self.selectedTrigger = nil

    -- TODO when implementing: Add fields programmatically
    -- self:AddField(StringField({name="name", title="Trigger Name"}))
    -- self:AddField(BooleanField({name="enabled", title="Enabled"}))
end

function RmlUiTriggerEditor:OnNewTrigger()
    Log.Notice("New trigger (not implemented)")
end

function RmlUiTriggerEditor:OnDeleteTrigger()
    Log.Notice("Delete trigger (not implemented)")
end

function RmlUiTriggerEditor:RefreshTriggerList()
    Log.Notice("Refresh trigger list (not implemented)")
end
