TextureUndoStack = LCS.class{}

function TextureUndoStack:init()
    self.stack = {
        -- ["originalTexture"] = {
        --     texture = "backupTexture", -- string
        --     dirty = dirtyBit, -- bool
        --     originalTextureObj = originalTextureObj -- table
        -- }
    }
    self.memorySize = 0
end

local function CalculateTextureMemorySize(texture)
    local texInfo = gl.TextureInfo(texture)
    local size = texInfo.xsize * texInfo.ysize * 4
    return size
end

-- API

function TextureUndoStack:PushStack(stackItem)
	for _, entry in pairs(stackItem) do
        self.memorySize = self.memorySize + CalculateTextureMemorySize(entry.texture)
	end

    table.insert(self.stack, stackItem)

    self:__PrintMemory()
end

function TextureUndoStack:RemoveFirst()
    local stackItem = self.stack[1]

    self:__RemoveStackItem(stackItem)

    table.remove(self.stack, 1)
    self:__PrintMemory()
end

function TextureUndoStack:PopStack()
    local stackItem = self.stack[#self.stack]

    self:__RestoreStackItem(stackItem)
    self:__RemoveStackItem(stackItem)

    table.remove(self.stack, #self.stack)
    self:__PrintMemory()
end


function TextureUndoStack:GetStack()
    return self.stack
end

-- PRIVATE

function TextureUndoStack:__RemoveStackItem(stackItem)
    if not stackItem then
        return
    end
	for original, entry in pairs(stackItem) do
		self.memorySize = self.memorySize - CalculateTextureMemorySize(entry.texture)
		gl.DeleteTexture(entry.texture)
    end
end

function TextureUndoStack:__RestoreStackItem(stackItem)
	for original, entry in pairs(stackItem) do
        gfx.Blit(entry.texture, original)
        entry.originalTextureObj.dirty = entry.dirty
	end
end

function TextureUndoStack:__PrintMemory()
    local mbSize = math.ceil(self.memorySize / 1024 / 1024)
    Log.Debug("Memory: " .. tostring(mbSize) .. "MB")
end
