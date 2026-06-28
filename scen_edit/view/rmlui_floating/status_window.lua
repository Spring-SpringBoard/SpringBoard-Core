SB.Include(Path.Join(SB.DIRS.SRC, 'view/floating/status_window_model.lua'))

RmlUiStatusWindow = LCS.class{}

function RmlUiStatusWindow:init()
    self.rmlPath = Path.Join(SB.DIRS.SRC, 'view/rml/floating/status_window.rml')
    self.model = StatusWindowModel()

    -- Data binding setup: create the model on the context before loading the document
    local context = SB.rmlui.context
    assert(context, "RmlUi context not initialized")
    self.data = {
        position = "X: 0, Y: 0, Z: 0. No selection",
        memory = "Memory 0 MB",
        version = self.model:GetVersionString(),
    }
    self.dataModel = context:OpenDataModel("status_window", self.data)
    assert(self.dataModel, "Status Window failed to create data model")

    -- Mark initial values dirty so bindings update
    self.dataModel:__SetDirty("position")
    self.dataModel:__SetDirty("memory")
    self.dataModel:__SetDirty("version")

    self.document = context:LoadDocument(self.rmlPath)
    assert(self.document, "Status Window failed to load document")

    -- Register view callbacks with model
    self.model.onStatusUpdate = function(statusText)
        if statusText ~= self.data.position then
            self.data.position = statusText
            self.dataModel:__SetDirty("position")
        end
    end
    self.model.onMemoryUpdate = function(memoryStr, memory, color)
        -- Convert Chili color codes to HTML color
        local htmlColor = "#01b414"  -- Green (OK)
        if memory > 500 then
            htmlColor = "#ff1432"  -- Red (DANGER)
        elseif memory > 300 then
            htmlColor = "#96960a"  -- Yellow (WARN)
        end
        local formatted = string.format('Memory <span style="color: %s;">%.0f MB</span>', htmlColor, memory)
        if formatted ~= self.data.memory then
            self.data.memory = formatted
            self.dataModel:__SetDirty("memory")
        end
    end
end

function RmlUiStatusWindow:Show()
    if self.document then
        self.document:Show()
    end
end

function RmlUiStatusWindow:Hide()
    if self.document then
        self.document:Hide()
    end
end

function RmlUiStatusWindow:Update()
    self.model:Update()
end
