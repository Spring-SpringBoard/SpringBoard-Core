LoadGUIStateCommand = Command:extends{}
LoadGUIStateCommand.className = "LoadGUIStateCommand"

function LoadGUIStateCommand:init(guiState)
    self.className = "LoadGUIStateCommand"
    self.guiState = guiState
end

function LoadGUIStateCommand:execute()
    local guiState = loadstring(self.guiState)()
    local brushes = guiState.brushes

    for name, brushes in pairs(brushes) do
        local brushManager = SB.model.brushManagers:GetBrushManager(name)
        brushManager:Load(brushes)
    end
end
