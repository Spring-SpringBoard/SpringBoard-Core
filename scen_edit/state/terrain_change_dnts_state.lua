TerrainChangeDNTSState = AbstractMapEditingState:extends{}
SB.Include("scen_edit/model/texture_manager.lua")

function TerrainChangeDNTSState:init(editorView)
    AbstractMapEditingState.init(self, editorView)
    self.rotation = 0
    self.patternTexture = self.editorView.fields["patternTexture"].value
    self.dnts           = self.editorView.fields["dnts"].value
    self.blendFactor    = self.editorView.fields["blendFactor"].value

    self.updateDelay    = 0.2
    self.applyDelay     = 0.02
end

function TerrainChangeDNTSState:Apply(x, z, applyAction)
    if not self.patternTexture then
        return
    end
    local colorIndex = tonumber(self.dnts) * applyAction

    local opts = {
        x = x - self.size/2,
        z = z - self.size/2,
        size = self.size,
        patternTexture = self.patternTexture,
        blendFactor = self.blendFactor,
        colorIndex = colorIndex,

        paintMode = "dnts",
    }
    local command = TerrainChangeTextureCommand(opts)
    SB.commandManager:execute(command)
end

function TerrainChangeDNTSState:DrawWorld()
    if not self.patternTexture then
        return
    end
    x, y = Spring.GetMouseState()
    local result, coords = Spring.TraceScreenRay(x, y, true)
    if result == "ground" then
        local x, z = coords[1], coords[3]
        local shape = SB.model.textureManager:GetTexture(self.patternTexture)
        self:DrawShape(shape, x, z)
    end
end

function TerrainChangeDNTSState:GetApplyParams(x, z, button)
    local applyAction = 1
    if button == 3 then
        applyAction = -1
    end
    return x, z, applyAction
end
