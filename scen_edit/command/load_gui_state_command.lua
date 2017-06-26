LoadGUIStateCommand = Command:extends{}
LoadGUIStateCommand.className = "LoadGUIStateCommand"

function LoadGUIStateCommand:init(guiState)
    self.className = "LoadGUIStateCommand"
    self.guiState = guiState
end

function LoadGUIStateCommand:execute()
    local guiState = loadstring(self.guiState)()
    local brushes = guiState.brushes

    for name, brush in pairs(brushes) do
        SB.savedBrushesRegistryData[name] = brush
    end
end
