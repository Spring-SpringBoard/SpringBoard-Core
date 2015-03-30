TerrainManager = Observable:extends{}

function TerrainManager:init()
    self.shapes = {}
end

function TerrainManager:addShape(name, value)
    self.shapes[name] = value
end

function TerrainManager:getShape(name)
    return self.shapes[name]
end