LoadMap = AbstractCommand:extends{}
LoadMap.className = "LoadMap"

local floatSize = 4

function LoadMap:init(deltaMap)
    self.className = "LoadMap"
    self.deltaMap = deltaMap
end

function LoadMap:execute()
    Spring.RevertHeightMap(0, 0, Game.mapSizeX, Game.mapSizeZ, 1)
    Spring.SetHeightMapFunc(function()
        --Spring.Echo("HEIGHTMAP LOAD")
        if self.deltaMap == nil or #self.deltaMap == 0 then
            return
        end
        local bufferSize = 100000 * floatSize

        local segmentNum = 0
        local totalSegments = math.ceil(#self.deltaMap / bufferSize)
        local dataSize = #self.deltaMap / floatSize
        --Spring.Echo("Segments : " .. totalSegments .. " Floats: " .. dataSize)

        local fetchSegment = function()
            if segmentNum >= totalSegments then
                return {}
            end
            local startIndx = 1 + segmentNum * bufferSize
            segmentNum = segmentNum + 1
            local str = self.deltaMap:sub(startIndx, startIndx + bufferSize)
            return VFS.UnpackF32(str, 1, bufferSize / floatSize) or {}
--            return VFS.UnpackF32(self.deltaMap, startIndx, bufferSize / floatSize) or {}
        end
        local data = fetchSegment()
        local i = 1
        local getData = function()
            local chunk = data[i]            
            i = i + 1
            if i > #data then
                data = fetchSegment()
                i = 1
            end
            return chunk
        end
        for x = 0, Game.mapSizeX, Game.squareSize do
            for z = 0, Game.mapSizeZ, Game.squareSize do
                local v = getData()

                Spring.SetHeightMap(x, z, v)

            end
        end
        --Spring.Echo("HEIGHTMAP LOAD DONE")
    end)
end
