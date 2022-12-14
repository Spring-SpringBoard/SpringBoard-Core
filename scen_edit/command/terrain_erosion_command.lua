TerrainErosionCommand = AbstractTerrainModifyCommand:extends{}
TerrainErosionCommand.className = "TerrainErosionCommand"

function TerrainErosionCommand:init(opts)
    self:__init(opts)
end

function TerrainErosionCommand:GetChangeFunction()
    return Spring.AddHeightMap
end

function TerrainErosionCommand:GenerateChanges(params)
    local startX = params.startX
    local startZ = params.startZ
    local parts  = params.parts
    local size   = params.size
    local isUndo = params.isUndo
    local map    = params.map

    local canUpper = self.opts.applyDirID >= 0
    local canLower = self.opts.applyDirID <= 0
    -- Strength should probably never be below 0 for this operation.
    -- We cannot make 0 the minimum value for strength in the UI,
    -- since we're using the same control for both add and set
    -- (although maybe we should separate them, for other reasons as well)
    -- if self.opts.strength < 0 then
    --     canUpper, canLower = canLower, canUpper
    -- end
    local height = self.opts.height

    local changes = {}

    -- localized loop vars
    -- local old, dh, d
    for x = 0, size, Game.squareSize do
        for z = 0, size, Game.squareSize do
            changes[x + z * parts] = 0
        end
    end

    for i = 1, 10 do
        self:SimulateDroplet(changes, startX + math.random() * size, startZ + math.random() * size, parts)
    end
    -- table.echo(changes)
    return changes
end

function TerrainErosionCommand:SimulateDroplet(changes, startX, startZ, parts)
    local dropletSpeedX = 0
    local dropletSpeedZ = 0
    local dropletPosX = startX
    local dropletPosZ = startZ

    -- Spring.Echo("START POS", dropletPosX, dropletPosZ)

    local idx
    for i = 1, 10 do
        local dropletMapPosX = Math.RoundInt(dropletPosX, Game.squareSize)
        local dropletMapPosZ = Math.RoundInt(dropletPosZ, Game.squareSize)

        idx = math.max(0, dropletMapPosX - startX) + math.max(0, dropletMapPosZ - startZ) * parts
        local dropletHeight = Spring.GetGroundHeight(dropletMapPosX, dropletMapPosZ) + (changes[idx] or 0)

        -- Spring.Echo("droplet", i, dropletMapPosX, dropletMapPosZ, dropletHeight)
        local minX = 0
        local minZ = 0
        local minHeight = dropletHeight
        for x = -Game.squareSize * 2, Game.squareSize * 2, Game.squareSize do
            for z = -Game.squareSize * 2, Game.squareSize * 2, Game.squareSize do
                idx = math.max(0, dropletMapPosX + x - startX) + math.max(0, dropletMapPosZ + z - startZ) * parts
                local height = Spring.GetGroundHeight(dropletMapPosX + x, dropletMapPosZ + z) + (changes[idx] or 0)
                if height < minHeight then
                    minHeight = height
                    minX = x
                    minZ = z
                end
            end
        end

        if dropletHeight <= minHeight then
            break
        end

        local deltaHeight = (dropletHeight - minHeight) * 0.2

        local destX = dropletMapPosX + minX
        local destZ = dropletMapPosZ + minZ

        if destX - startX > 0 and destZ - startZ > 0 then
            idx = math.max(0, dropletMapPosX - startX) + math.max(0, dropletMapPosZ - startZ) * parts
            if changes[idx] ~= nil then
                changes[idx] = changes[idx] - deltaHeight
            end
            for x = -Game.squareSize * 2, Game.squareSize * 2, Game.squareSize do
                for z = -Game.squareSize * 2, Game.squareSize * 2, Game.squareSize do
                    if x ~= 0 and z ~= 0 then
                        idx = math.max(0, dropletMapPosX - startX + x) + math.max(0, dropletMapPosZ - startZ + z) * parts
                        if changes[idx] ~= nil then
                            changes[idx] = changes[idx] - deltaHeight * 0.2
                        end
                    end
                end
            end
            idx = math.max(0, destX - startX) + math.max(0, destZ - startZ) * parts
            if changes[idx] ~= nil then
                changes[idx] = changes[idx] + deltaHeight
            else
                Spring.Echo("NIL", dropletMapPosX + minX - startX, dropletMapPosZ + minZ - startZ)
            end
            for x = -Game.squareSize * 2, Game.squareSize * 2, Game.squareSize do
                for z = -Game.squareSize * 2, Game.squareSize * 2, Game.squareSize do
                    if x ~= 0 and z ~= 0 then
                        idx = math.max(0, dropletMapPosX + minX - startX + x) + math.max(0, dropletMapPosZ + minZ - startX + z) * parts
                        if changes[idx] ~= nil then
                            changes[idx] = changes[idx] + deltaHeight * 0.2
                        end
                    end
                end
            end

            dropletPosX = dropletPosX + minX
            dropletPosZ = dropletPosZ + minZ
        else
            Spring.Echo("NO NEXT", destX, destZ, startX, startZ)
        end
    end

    -- Spring.GetGroundHeight
    -- local left = Spring.GetGroundHeight(startX - size, startZ)
    -- local right = Spring.GetGroundHeight(startX + size, startZ)
    -- local top = Spring.GetGroundHeight(startX, startZ + size)
    -- local bottom = Spring.GetGroundHeight(startX, startZ + size)




    -- for x = 0, size, Game.squareSize do
    --     for z = 0, size, Game.squareSize do
    --         d = map[x + z * parts]
    --         if d > 0 then
    --             old = Spring.GetGroundHeight(x + startX, z + startZ)
    --             if height > old then
    --                 if canUpper then
    --                     dh = math.min(d, height - old)
    --                     changes[x + z * parts] = dh
    --                 end
    --             else
    --                 if canLower then
    --                     dh = math.min(d, old - height)
    --                     changes[x + z * parts] = -dh
    --                 end
    --             end
    --         end
    --     end
    -- end
end

function TerrainErosionCommand:CalculateAverage()
end