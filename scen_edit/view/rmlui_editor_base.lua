-- RmlUi Base Editor Class
-- Provides AddField() API for editors - implementation-agnostic!
-- ALL editors use ONE generic_editor.rml template that gets populated dynamically

-- Only load if RmlUi is available
if not RmlUi then
    return
end

RmlUiEditorBase = LCS.class{}

function RmlUiEditorBase:init()
    self.fields = {}
    self.document = nil
    self.fieldContainer = nil
    self.editorTitle = "Editor"  -- Override in subclass
end

function RmlUiEditorBase:Initialize()
    -- Load the ONE generic editor template
    local rmlPath = Path.Join(SB.DIRS.SRC, 'view/rml/generic_editor.rml')
    self.document = SB.rmlui:LoadDocument(rmlPath, false)

    if not self.document then
        Log.Error("Failed to load generic editor template")
        return false
    end

    -- Set title
    local titleElement = self.document:GetElementById("editor-title")
    if titleElement then
        titleElement.inner_rml = self.editorTitle
    end

    -- Get field container where fields will be injected
    self.fieldContainer = self.document:GetElementById("editor-content")

    Log.Notice(self.editorTitle .. " initialized (programmatic)")
    return true
end

function RmlUiEditorBase:Show()
    if self.document then
        self.document:Show()
    end
end

function RmlUiEditorBase:Hide()
    if self.document then
        self.document:Hide()
    end
end

function RmlUiEditorBase:Close()
    if self.document then
        self.document:Close()
        self.document = nil
    end
end

function RmlUiEditorBase:AddField(field)
    -- Just collect fields, don't render yet!
    -- Rendering happens in Finalize() for efficiency
    table.insert(self.fields, field)
end

function RmlUiEditorBase:Finalize(children, opts)
    -- This is where ALL fields are rendered in one shot
    -- Matches original Chili API: editor calls Finalize() at end

    -- Generate RML for all fields in one go
    local allFieldsRml = ""
    for _, field in ipairs(self.fields) do
        allFieldsRml = allFieldsRml .. field:GenerateRml()
    end

    -- Set the field container's content
    if self.fieldContainer then
        self.fieldContainer.inner_rml = allFieldsRml

        -- Store reference so fields can update their values
        for _, field in ipairs(self.fields) do
            field.element = self.fieldContainer
        end
    end

    -- Subclasses can override to do additional finalization
    Log.Notice("Editor finalized with " .. #self.fields .. " fields")
end

function RmlUiEditorBase:RenderAllFields()
    -- Helper method if you need to re-render all fields
    if not self.fieldContainer then
        Log.Warning("Cannot render fields: no field container set")
        return
    end

    -- Generate RML for all fields
    local allFieldsRml = ""
    for _, field in ipairs(self.fields) do
        allFieldsRml = allFieldsRml .. field:GenerateRml()
        field.element = self.fieldContainer
    end

    -- Set all at once (efficient single DOM update)
    self.fieldContainer.inner_rml = allFieldsRml
end

function RmlUiEditorBase:GetFieldValue(fieldName)
    for _, field in ipairs(self.fields) do
        if field.name == fieldName then
            return field:GetValue()
        end
    end
    return nil
end

function RmlUiEditorBase:SetFieldValue(fieldName, value)
    for _, field in ipairs(self.fields) do
        if field.name == fieldName then
            field:SetValue(value)
            return
        end
    end
end

function RmlUiEditorBase:GetAllFieldValues()
    local values = {}
    for _, field in ipairs(self.fields) do
        values[field.name] = field:GetValue()
    end
    return values
end

function RmlUiEditorBase:ClearFields()
    self.fields = {}
    if self.fieldContainer then
        self.fieldContainer.inner_rml = ""
    end
end

-- Example usage in an editor:
--[[
    MyEditor = RmlUiEditorBase:extends{}

    function MyEditor:init()
        self:super("init")

        -- NO RML needed! Just add fields programmatically
        self:AddField(RmlUiStringField({name="name", title="Name", value="Trigger 1"}))
        self:AddField(RmlUiBooleanField({name="enabled", title="Enabled", value=true}))
        self:AddField(RmlUiNumericField({name="x", title="X Position", value=100}))

        -- That's it! The fields handle all RML generation
    end
]]--
