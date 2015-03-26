TerrainChangeTextureCommand = UndoableCommand:extends{}
TerrainChangeTextureCommand.className = "TerrainChangeTextureCommand"

function TerrainChangeTextureCommand:init(x, z, size, textureName, paintTexture)
    self.className = "TerrainChangeTextureCommand"
    self.x, self.z, self.size = x, z, size
    self.textureName = textureName
    self.paintTexture = paintTexture
end

function TerrainChangeTextureCommand:execute()
    self.x, self.z, self.size = math.floor(self.x), math.floor(self.z), math.floor(self.size)
    local cmd = WidgetTerrainChangeTextureCommand(self.x, self.z, self.size, self.textureName, self.paintTexture)
    SCEN_EDIT.commandManager:execute(cmd, true)
end

function TerrainChangeTextureCommand:unexecute()
    local cmd = WidgetTerrainChangeTextureCommand(self.x, self.z, self.size, self.textureName, self.paintTexture, true)
    SCEN_EDIT.commandManager:execute(cmd, true)
end