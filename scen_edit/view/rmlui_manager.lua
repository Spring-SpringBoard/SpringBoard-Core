--- RmlUi Manager
--- Manages RmlUi context and documents

-- Only load if RmlUi is available
if not RmlUi then
    return
end

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

    if not RmlUi then
        Log.Warning("RmlUi not available - SpringBoard requires BAR Engine 105.1.1+")
        return false
    end

    local vsx, vsy = Spring.GetViewGeometry()
    self.context = RmlUi.CreateContext("SpringBoard", vsx, vsy)

    if not self.context then
        Log.Error("Failed to create RmlUi context")
        return false
    end

    self.initialized = true
    Log.Notice("RmlUi initialized successfully")
    return true
end

function RmlUiManager:LoadDocument(path, show, isDialog)
    if not self.initialized then
        Log.Error("RmlUiManager not initialized")
        return nil
    end

    local doc = self.context:LoadDocument(path)
    if not doc then
        Log.Error("Failed to load RmlUi document: " .. path)
        return nil
    end

    -- For dialogs, ensure transparent background and proper z-index
    if isDialog then
        -- Get the body element and ensure it's transparent
        local body = doc.body
        if body and body.SetProperty then
            body:SetProperty("background-color", "transparent")
            body:SetProperty("z-index", "10000")
        end
    end

    if show then
        doc:Show()
    end

    table.insert(self.documents, doc)
    return doc
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

    local modState = 0
    if down then
        return self.context:ProcessMouseButtonDown(button, modState) == 1
    else
        return self.context:ProcessMouseButtonUp(button, modState) == 1
    end
end

function RmlUiManager:KeyEvent(key, down, mods)
    if not self.initialized or not self.context then
        return false
    end

    local modState = 0
    if type(mods) == "table" then
        if mods.shift then modState = modState + 1 end
        if mods.ctrl then modState = modState + 2 end
        if mods.alt then modState = modState + 4 end
        if mods.meta then modState = modState + 8 end
    end

    if down then
        return self.context:ProcessKeyDown(key, modState) == 1
    else
        return self.context:ProcessKeyUp(key, modState) == 1
    end
end

function RmlUiManager:TextInput(unicode)
    if not self.initialized or not self.context then
        return false
    end

    local text
    if type(unicode) == "number" then
        text = utf8.char(unicode)
    else
        text = tostring(unicode)
    end

    return self.context:ProcessTextInput(text) == 1
end

-- Global instance
SB.rmlui = RmlUiManager()
