HeightMap = LCS.class{}

function HeightMap:init()
    self.segments = {}
    self.segmentSize = 1024*1024
end

function HeightMap:Serialize()
    self.segments = {}
    local segment = {}
    local i = 1
    local totalSaved = 0
    for x = 0, Game.mapSizeX, Game.squareSize do
        for z = 0, Game.mapSizeZ, Game.squareSize do
            local groundHeight = Spring.GetGroundHeight(x, z)
            local origGroundHeight = Spring.GetGroundOrigHeight(x, z)
            local deltaHeight = groundHeight - origGroundHeight
            if deltaHeight ~= 0 then
                if i > self.segmentSize then
                    table.insert(self.segments, segment)
                    i = 1
                    segment = {}
                end
                segment[i] = { x, z, groundHeight }
                i = i + 1
                totalSaved = totalSaved + 1
            end
        end
    end
--    Spring.Echo("Total saved: ", totalSaved)
    table.insert(self.segments, segment)
end

function HeightMap:Load()
    Spring.RevertHeightMap(0, 0, Game.mapSizeX, Game.mapSizeZ, 1)
    Spring.SetHeightMapFunc(function()
        local totalLoaded = 0
        for _, segment in pairs(self.segments) do
            for _, point in pairs(segment) do
                local x, z, y = unpack(point)
                Spring.SetHeightMap(x, z, y)
                totalLoaded = totalLoaded + 1
            end
        end
--        Spring.Echo("Total loaded: ", totalLoaded)
    end)
end

