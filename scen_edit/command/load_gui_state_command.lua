LoadGUIStateCommand = Command:extends{}
LoadGUIStateCommand.className = "LoadGUIStateCommand"

function LoadGUIStateCommand:init(guiState)
    self.className = "LoadGUIStateCommand"
    -- Since the introduction of the data packing/unpacking, is much more
    -- efficient passing tables than strings
    if guiState then
        self.guiState = loadstring(guiState)()
    end
end

function LoadGUIStateCommand:execute()
    local brushes = self.guiState.brushes or {}
    for name, brushData in pairs(brushes) do
        local brushManager = SB.model.brushManagers:GetBrushManager(name)
        brushManager:Load(brushData)
    end

    local editors = self.guiState.editors or {}

    SB.delay(function()
    SB.delay(function()
        for name, editorData in pairs(editors) do
            if not SB.editorRegistry[name].no_serialize then
                SB.editors[name]:Load(editorData)
            end
        end
    end)
    end)
end
