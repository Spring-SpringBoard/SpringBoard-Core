GrassEditingState = AbstractMapEditingState:extends{}
SB.Include("scen_edit/model/texture_manager.lua")

function GrassEditingState:init(editorView)
    AbstractMapEditingState.init(self, editorView)

    self.updateDelay    = 0.2
    self.applyDelay     = 0.02
end

function GrassEditingState:Apply(x, z)
    local _, _, addMode, _, _ = Spring.GetMouseState()
    local opts = {
        x = x - self.size,
        z = z - self.size,
        size = self.size,
        addMode = addMode,
    }
    local command = TerrainGrassCommand(opts)
    SB.commandManager:execute(command)
end

function GrassEditingState:DrawWorld()
    x, y = Spring.GetMouseState()
    local result, coords = Spring.TraceScreenRay(x, y, true)
    if result == "ground" then
        local x, z = coords[1], coords[3]
        gl.PushMatrix()
        gl.Color(0, 1, 0, 0.3)
        --gl.DepthTest(true)
        gl.Utilities.DrawGroundCircle(x, z, self.size)
        gl.PopMatrix()
    end
end
