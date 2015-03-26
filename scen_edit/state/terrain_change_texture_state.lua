TerrainChangeTextureState = AbstractEditingState:extends{}
SCEN_EDIT.Include("scen_edit/model/texture_manager.lua")

--FIXME: remove this default pen
local penTexture = "bitmaps/detailtex2.bmp"

function TerrainChangeTextureState:startChanging()
    if not self.startedChanging then
        local cmd = SetMultipleCommandModeCommand(true)
        SCEN_EDIT.commandManager:execute(cmd)
        self.startedChanging = true
    end
end

function TerrainChangeTextureState:stopChanging()
    if self.startedChanging then
        local cmd = SetMultipleCommandModeCommand(false)
        SCEN_EDIT.commandManager:execute(cmd)
        self.startedChanging = false
    end
end

function TerrainChangeTextureState:init(terrainEditorView)
    self.terrainEditorView = terrainEditorView
    self.paintTexture   = self.terrainEditorView.paintTexture
    self.penTexture     = self.terrainEditorView.penTexture
    self.size           = self.terrainEditorView.fields["size"].value
    self.texScale       = self.terrainEditorView.fields["texScale"].value
    self.detailTexScale = self.terrainEditorView.fields["detailTexScale"].value
    self.mode           = self.terrainEditorView.fields["mode"].value

    if SCEN_EDIT.textureManager == nil then
        SCEN_EDIT.textureManager = TextureManager()
    end
end

function TerrainChangeTextureState:SendCommand(cmd)
    local currentFrame = Spring.GetGameFrame()
    if not self.lastChangeFrame or currentFrame - self.lastChangeFrame >= 0 then
        self.lastChangeFrame = currentFrame
        SCEN_EDIT.commandManager:execute(cmd)
    end
end

function TerrainChangeTextureState:MousePress(x, y, button)
    if button == 1 then
        local result, coords = Spring.TraceScreenRay(x, y, true)
        if result == "ground"  then
            self:startChanging()
            local x, z = coords[1] - self.size, coords[3] - self.size
            local opts = {
                x = x,
                z = z,
                size = self.size,
                penTexture = self.penTexture,
                paintTexture = self.paintTexture,
                texScale = self.texScale,
                detailTexScale = self.detailTexScale,
                mode = self.mode,
            }
            local command = TerrainChangeTextureCommand(opts)
            self:SendCommand(command)
            return true
        end
    elseif button == 3 then
        self:stopChanging()
        SCEN_EDIT.stateManager:SetState(DefaultState())
        self.terrainEditorView:Select(0)
    end
end

function TerrainChangeTextureState:MouseMove(x, y, dx, dy, button)
    local result, coords = Spring.TraceScreenRay(x, y, true)
    if result == "ground"  then
        local x, z = coords[1] - self.size, coords[3] - self.size
        local opts = {
            x = x,
            z = z,
            size = self.size,
            penTexture = self.penTexture,
            paintTexture = self.paintTexture,
            texScale = self.texScale,
            detailTexScale = self.detailTexScale,
            mode = self.mode
        }
        local command = TerrainChangeTextureCommand(opts)
        self:SendCommand(command)
    end
end

function TerrainChangeTextureState:MouseRelease(x, y, button)
    self:stopChanging()
end

function TerrainChangeTextureState:KeyPress(key, mods, isRepeat, label, unicode)
    if self:super("KeyPress", key, mods, isRepeat, label, unicode) then
        return true
    end
end

function TerrainChangeTextureState:MouseWheel(up, value)
    local _, ctrl = Spring.GetModKeyState()
    if ctrl then
        local size
        if up then
            size = self.size + self.size * 0.2 + 2
        else
            size = self.size - self.size * 0.2 - 2
        end
        self.terrainEditorView:SetNumericField("size", size)
        return true
    end
end

function TerrainChangeTextureState:DrawWorld()
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
