TerrainMetalCommand = Command:extends{}
TerrainMetalCommand.className = "TerrainMetalCommand"

function TerrainMetalCommand:init(opts)
    self.className = "TerrainMetalCommand"
    self.opts = opts
end

function TerrainMetalCommand:GenerateChanges(opts)
    local amount = math.ceil(opts.amount)
    local size = opts.size

    if not opts.addMode then
        amount = 0
    end

    local changes = {}

    local partSize = Game.squareSize
    for x = 0, 2*size, partSize do
        local dx = size - x
        local cx = (x + opts.x) / 16
        cx = cx - cx % 1
        for z = 0, 2*size, partSize do
            local dz = size - z
            if dx*dx + dz*dz <= size * size then
                local cz = (z + opts.z) / 16
                cz = cz - cz % 1
                local change = math.ceil(amount - Spring.GetMetalAmount(cx, cz))
                if change ~= 0 then
                    table.insert(changes, {
                        x = cx,
                        z = cz,
                        value = change,
                    })
                end
            end
        end
    end

    return changes
end

function TerrainMetalCommand:execute()
    if not self.changes then
        self.changes = self:GenerateChanges(self.opts)
    end
    self:_ApplyChanges(self.changes, false)
end

function TerrainMetalCommand:unexecute()
    self:_ApplyChanges(self.changes, true)
end

function TerrainMetalCommand:_ApplyChanges(changes, isUndo)
    if not isUndo then
        for _, change in ipairs(changes) do
            Spring.SetMetalAmount(change.x, change.z, change.value)
        end
    else
        for _, change in ipairs(changes) do
            Spring.SetMetalAmount(change.x, change.z, -change.value)
        end
    end
end
