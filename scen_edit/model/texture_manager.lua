TextureManager = Observable:extends{}

function TextureManager:init()
    self:super('init')
    self.TEXTURE_SIZE = 1024

    self.mapFBOTextures = {}
    self.oldMapFBOTextures = {}
	self.oldShadingTextures = {}
    self.stack = {}
	self.stackSize = 0
    self.tmps = {}

    self.cachedTextures = {}
    self.cachedTexturesMapping = {}
    self.maxCache = 20

	self.shadingTextures = {}
	
	self.shadingTextureNaming = {
		{
			name = "specular",
			engineName = "$ssmf_specular",
		}, 
-- 		{
-- 			name = "detail",
-- 			engineName = "ground_detail",
-- 		}, 
		{
			name = "normal",
			engineName = "$ssmf_normals",
		}
	}
    SCEN_EDIT.delayGL(function()
        self:generateMapTextures()
    end)
end

function TextureManager:createMapTexture(notFBO)
    return gl.CreateTexture(self.TEXTURE_SIZE, self.TEXTURE_SIZE, {
        border = false,
        min_filter = GL.LINEAR,
        mag_filter = GL.LINEAR,
        wrap_s = GL.CLAMP_TO_EDGE,
        wrap_t = GL.CLAMP_TO_EDGE,
        fbo = not notFBO,
    })
end

local shader
function TextureManager:SetupShader()
	local vertProg = VFS.LoadFile("shaders/SMFVertProg.glsl")
	local fragProg = VFS.LoadFile("shaders/SMFFragProg.glsl")
	shader = Shaders.Compile({
		vertex = [[
void main(void)
{
	gl_Position = gl_ModelViewProjectionMatrix * gl_Vertex;

}
]],
		fragment = [[
uniform ivec2 texSquare;

varying vec2 diffuseTexCoords;
uniform sampler2D diffuseTex;
void main(void)
{
    vec2 diffTexCoords = diffuseTexCoords;
    vec4 diffuseCol = texture2D(diffuseTex, diffTexCoords);
    gl_FragColor = diffuseCol;
} 
]]
	}, "TextureManager:SetupShader")
	Spring.SetMapShader(shader, shader)
end

function TextureManager:generateMapTextures()
    Log.Debug("Generating textures...")
    local oldMapTexture = self:createMapTexture(false)

    for i = 0, math.floor(Game.mapSizeX / self.TEXTURE_SIZE) do
        self.mapFBOTextures[i] = {}
        for j = 0, math.floor(Game.mapSizeZ / self.TEXTURE_SIZE) do
            local mapTexture = self:createMapTexture()

            Spring.GetMapSquareTexture(i, j, 0, oldMapTexture)
            self:Blit(oldMapTexture, mapTexture)

            self.mapFBOTextures[i][j] = {
                texture = mapTexture,
                dirty = false,
            }
            Spring.SetMapSquareTexture(i, j, mapTexture)
        end
    end
	
	self.shadingTextures = {}
	for _, texture in pairs(self.shadingTextureNaming) do
		local name, engineName = texture.name, texture.engineName
		Log.Notice("engine texture: " .. tostring(name))
		local success = Spring.SetMapShadingTexture(engineName, "")
		if not success then
			Log.Error("Failure to set texture: " .. tostring(name) .. ", engine name: " .. tostring(engineName))
		end
		--local tex = self:createMapTexture()
		local sizeX, sizeZ--[[ = Game.mapSizeX/2, Game.mapSizeZ/2]]
		local texInfo = gl.TextureInfo(engineName)
		if texInfo and texInfo.xsize > 0 then
			sizeX, sizeZ = texInfo.xsize, texInfo.ysize
		end
		
		if sizeX and sizeZ then
			local texFormat
			if name == "normal" then
				GL_RG = 34836
				texFormat = GL_RG
			end
			local tex
			if name ~= "detail" then
				tex = gl.CreateTexture(sizeX, sizeZ, {
					border = false,
					min_filter = GL.LINEAR,
					mag_filter = GL.LINEAR,
					wrap_s = GL.CLAMP_TO_EDGE,
					wrap_t = GL.CLAMP_TO_EDGE,
					fbo = true,
					format = texFormat,
				})
			else
				sizeX, sizeZ = math.floor(sizeX * 0.02), math.floor(sizeZ * 0.02)
				sizeX, sizeZ = 128, 128
				tex = gl.CreateTexture(sizeX, sizeZ, {
					border = false,
					min_filter = GL.LINEAR,
					mag_filter = GL.LINEAR,
					wrap_s = GL.REPEAT,
					wrap_t = GL.REPEAT,
					fbo = true,
					format = texFormat,
				})
			end
	-- 		local engineTex = gl.Texture()
			self:Blit(engineName, tex)
			self.shadingTextures[name] = tex
			Spring.SetMapShadingTexture(engineName, tex)
		end
	end
--  	self:SetupShader()
end

function TextureManager:GetTMPs(num)
    for i = #self.tmps + 1, num do
        table.insert(self.tmps, self:createMapTexture())
    end
    local tmps = {}
    for i = 1, num do
        table.insert(tmps, self.tmps[i])
    end
    return tmps
end

function TextureManager:resetMapTextures()
    for i, v in pairs(self.mapFBOTextures) do
        for j, textureObj in pairs(v) do
            gl.DeleteTexture(textureObj.texture)
            Spring.SetMapSquareTexture(i, j, "")
        end
    end
    self.mapFBOTextures = {}
end

function TextureManager:getMapTexture(x, z)
    local i, j = math.floor(x / self.TEXTURE_SIZE), math.floor(z / self.TEXTURE_SIZE)
    return self.mapFBOTextures[i][j]
end

function TextureManager:backupMapShadingTexture(name)
	self:getOldShadingTexture(name)
end

function TextureManager:getOldShadingTexture(name)
	if self.oldShadingTextures[name] == nil then
		local texture = self.shadingTextures[name]
		local texInfo = gl.TextureInfo(texture)
		local texSizeX, texSizeZ = texInfo.xsize, texInfo.ysize
		local oldTexture = gl.CreateTexture(texSizeX, texSizeZ, {
			border = false,
			min_filter = GL.LINEAR,
			mag_filter = GL.LINEAR,
			wrap_s = GL.CLAMP_TO_EDGE,
			wrap_t = GL.CLAMP_TO_EDGE,
			fbo = true,
		})
		self:Blit(texture, oldTexture)
		
		self.oldShadingTextures[name] = oldTexture
	end
	return self.oldShadingTextures[name]
end

function TextureManager:getOldMapTexture(i, j)
    if self.oldMapFBOTextures[i] == nil then
        self.oldMapFBOTextures[i] = {}
    end
    if self.oldMapFBOTextures[i][j] == nil then
        -- doesn't exist so we create it
        local oldTexture = self:createMapTexture()

        local mapTexture = self.mapFBOTextures[i][j].texture

        self:Blit(mapTexture, oldTexture)
        local oldTextureObj = {
            texture = oldTexture,
            dirty = mapTexture.dirty,
        }
        self.oldMapFBOTextures[i][j] = oldTextureObj
    end

    return self.oldMapFBOTextures[i][j]
end

function TextureManager:getMapTextures(startX, startZ, endX, endZ)
    local textures = {}
    local textureSize = self.TEXTURE_SIZE

    local i1 = math.max(0, math.floor(startX / textureSize))
    local i2 = math.min(math.floor(Game.mapSizeX / textureSize), 
                        math.floor(endX / textureSize))
    local j1 = math.max(0, math.floor(startZ / textureSize))
    local j2 = math.min(math.floor(Game.mapSizeZ / textureSize), 
                        math.floor(endZ / textureSize))

    for i = i1, i2 do
        for j = j1, j2 do
            table.insert(textures, { 
                self.mapFBOTextures[i][j], self:getOldMapTexture(i, j),
                { startX - i * textureSize, startZ - j * textureSize } 
            })
        end
    end

    return textures
end

function TextureManager:Blit(tex1, tex2)
	gl.Blending("disable")
    gl.Texture(tex1)
    gl.RenderToTexture(tex2, function()
        gl.TexRect(-1,-1, 1, 1, 0, 0, 1, 1)
    end)
    gl.Texture(false)
end

function TextureManager:CacheTexture(name)
    SCEN_EDIT.delayGL(function()
        if self.cachedTexturesMapping[name] ~= nil then
            return
        end
        -- maximum number of textures exceeded
        if #self.cachedTextures > self.maxCache then
            local obj = self.cachedTextures[1]
            gl.DeleteTexture(obj.texture)
            self.cachedTexturesMapping[obj.name] = nil
            table.remove(self.cachedTextures, 1)
        end

        local texInfo = gl.TextureInfo(name)
        local texture = gl.CreateTexture(texInfo.xsize, texInfo.ysize, {
            fbo = true,
        })
        self:Blit(name, texture)
        local obj = { texture = texture, name = name }
        self.cachedTexturesMapping[name] = obj
        table.insert(self.cachedTextures, obj)
    end)
end

function TextureManager:GetTexture(name)
    local cachedTex = self.cachedTexturesMapping[name]
    if cachedTex ~= nil then
        return cachedTex.texture
    else
        return name
    end
end

function TextureManager:_CalculateTextureMemorySize(texture)
	local texInfo = gl.TextureInfo(texture)
	local size = texInfo.xsize * texInfo.ysize * 4
	return size
end

function TextureManager:PushStack()
	local stackItem = {
		diffuse = self.oldMapFBOTextures,
	}
	for name, texture in pairs(self.oldShadingTextures) do
		stackItem[name] = texture
		self.stackSize = self.stackSize + self:_CalculateTextureMemorySize(texture)
	end
	
	for _, row in pairs(stackItem.diffuse) do
		for _, textureObj in pairs(row) do
			self.stackSize = self.stackSize + self:_CalculateTextureMemorySize(textureObj.texture)
		end
	end
	
	table.insert(self.stack, stackItem)
	self.oldMapFBOTextures = {}
	self.oldShadingTextures = {}
	
	self:PrintMemory()
end

function TextureManager:RemoveStackItem(stackItem)
    if not stackItem then
        return
    end
	for name, value in pairs(stackItem) do
		if name == "diffuse" then
			local oldTextures = value
			for i, v in pairs(oldTextures) do
				for j, oldTextureObj in pairs(v) do
					self.stackSize = self.stackSize - self:_CalculateTextureMemorySize(oldTextureObj.texture)
					
					gl.DeleteTexture(oldTextureObj.texture)
				end
			end
		else
			self.stackSize = self.stackSize - self:_CalculateTextureMemorySize(value)
			gl.DeleteTexture(value)
		end
	end
end

function TextureManager:RestoreStackItem(stackItem)
	for name, value in pairs(stackItem) do
		if name == "diffuse" then
			local oldTextures = value
			for i, v in pairs(oldTextures) do
				for j, oldTextureObj in pairs(v) do
					
					local mapTextureObj = self.mapFBOTextures[i][j]
					local mapTexture = mapTextureObj.texture
					self:Blit(oldTextureObj.texture, mapTexture)
					mapTextureObj.dirty = oldTextureObj.dirty
				end
			end
		else
			local shadingTex = self.shadingTextures[name]
			self:Blit(value, shadingTex)
		end
	end
end

function TextureManager:RemoveFirst()
	local stackItem = self.stack[1]
	
	self:RemoveStackItem(stackItem)

	table.remove(self.stack, 1)
	self:PrintMemory()
end

function TextureManager:PopStack()
	local stackItem = self.stack[#self.stack]
	
	self:RestoreStackItem(stackItem)
	self:RemoveStackItem(stackItem)

	self.oldMapFBOTextures = {}
	self.oldShadingTextures = {}
	
	table.remove(self.stack, #self.stack)
	self:PrintMemory()
end

function TextureManager:PrintMemory()
	local mbSize = math.ceil(self.stackSize / 1024 / 1024)
	Log.Debug("Memory: " .. tostring(mbSize) .. "MB")
end
