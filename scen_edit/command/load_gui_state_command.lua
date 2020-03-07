LoadGUIStateCommand = Command:extends{}
LoadGUIStateCommand.className = "LoadGUIStateCommand"

function LoadGUIStateCommand:init(guiState)
    -- Since the introduction of the data packing/unpacking, is much more
    -- efficient passing tables than strings
    if guiState then
        self.guiState = loadstring(guiState)()
    end
end

function LoadGUIStateCommand:execute()
    local editors = self.guiState.editors or {}

    SB.delay(function()
    SB.delay(function()
        for name, editorData in pairs(editors) do
            if SB.editorRegistry[name] == nil or SB.editors[name] == nil then
                Log.Warning("Missing Editor in registry: ", name)
            elseif not SB.editorRegistry[name].no_serialize then
                SB.editors[name]:Load(editorData)
            end
        end

        -- We also want to furher delay brush loading to ensure all necessary editors have been created
        SB.delay(function()
            local brushes = self.guiState.brushes or {}
            for name, brushData in pairs(brushes) do
                local brushManager = SB.model.brushManagers:GetBrushManager(name)
                brushManager:Load(brushData)
            end
        end)
    end)
    end)
end
