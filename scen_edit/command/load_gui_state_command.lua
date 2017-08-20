LoadGUIStateCommand = Command:extends{}
LoadGUIStateCommand.className = "LoadGUIStateCommand"

function LoadGUIStateCommand:init(guiState)
    self.className = "LoadGUIStateCommand"
    self.guiState = guiState
end

function LoadGUIStateCommand:execute()
    local guiState = loadstring(self.guiState)()

    local brushes = guiState.brushes or {}
    for name, brushData in pairs(brushes) do
        local brushManager = SB.model.brushManagers:GetBrushManager(name)
        brushManager:Load(brushData)
    end

    local editors = guiState.editors or {}

    SB.delay(function()
    SB.delay(function()
        for name, editorData in pairs(editors) do
            if not SB.editorRegistry[name].dont_save then
                SB.editors[name]:Load(editorData)
            end
        end
    end)
    end)
end
