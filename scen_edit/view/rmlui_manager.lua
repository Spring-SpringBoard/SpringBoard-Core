--- RmlUi Manager
--- Manages RmlUi context and documents

RmlUiManager = LCS.class{}

function RmlUiManager:init()
    self.context = nil
    self.documents = {}
    self.initialized = false
end

function RmlUiManager:Initialize()
    if self.initialized then
        return true
    end

    if not Spring.RmlUi then
        Log.Warning("RmlUi not available - SpringBoard requires BAR Engine 105.1.1+")
        return false
    end

    local vsx, vsy = Spring.GetViewGeometry()
    self.context = Spring.RmlUi.CreateContext("SpringBoard", vsx, vsy)

    if not self.context then
        Log.Error("Failed to create RmlUi context")
        return false
    end

    self.initialized = true
    Log.Notice("RmlUi initialized successfully")
    return true
end

function RmlUiManager:LoadDocument(path, show)
    if not self.initialized then
        Log.Error("RmlUiManager not initialized")
        return nil
    end

    local doc = self.context:LoadDocument(path)
    if not doc then
        Log.Error("Failed to load RmlUi document: " .. path)
        return nil
    end

    if show then
        doc:Show()
    end

    table.insert(self.documents, doc)
    return doc
end

function RmlUiManager:UpdateDimensions()
    if not self.initialized or not self.context then
        return
    end

    local vsx, vsy = Spring.GetViewGeometry()
    self.context:SetDimensions(vsx, vsy)
end

function RmlUiManager:Render()
    if not self.initialized or not self.context then
        return
    end

    self.context:Render()
end

function RmlUiManager:Update()
    if not self.initialized or not self.context then
        return
    end

    self.context:Update()
end

function RmlUiManager:MouseMove(x, y, dx, dy)
    if not self.initialized or not self.context then
        return false
    end

    return self.context:ProcessMouseMove(x, y, 0) == 1
end

function RmlUiManager:MouseButton(x, y, button, down)
    if not self.initialized or not self.context then
        return false
    end

    return self.context:ProcessMouseButtonEvent(button, down) == 1
end

function RmlUiManager:KeyEvent(key, down, mods)
    if not self.initialized or not self.context then
        return false
    end

    -- Convert Spring key to RmlUi key if needed
    return self.context:ProcessKeyEvent(key, down) == 1
end

function RmlUiManager:TextInput(unicode)
    if not self.initialized or not self.context then
        return false
    end

    return self.context:ProcessTextInput(unicode) == 1
end

-- Global instance
SB.rmlui = RmlUiManager()
