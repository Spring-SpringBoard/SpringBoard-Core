-- The temp texture functionality provides texture copies on demand.
-- The copies aren't destroyed, as creating and destroying textures can be expensive.
-- They are cached here, and provided when necessary.
-- Users request a list of textures to be copied, which can be of various sizes and types

function Graphics:__InitTempTextures()
	self.__tmpsByCategory = {}
end

function Graphics:__GetTemp(texInfo)
	-- give away one of the free textures if they exist
	local category = ('%d_%d'):format(texInfo.xsize, texInfo.ysize)

	local tmps = self.__tmpsByCategory[category]
	if tmps == nil then
		tmps = {}
		self.__tmpsByCategory[category] = tmps
	end

	for _, tmp in ipairs(tmps) do
		if tmp.free then
			tmp.free = false
			return tmp
		end
	end

	local tmp = {
		free = false,
		texture = gl.CreateTexture(texInfo.xsize, texInfo.ysize, {
			border = false,
			min_filter = GL.LINEAR,
			mag_filter = GL.LINEAR,
			wrap_s = GL.CLAMP_TO_EDGE,
			wrap_t = GL.CLAMP_TO_EDGE,
			fbo = true,
		})
	}
	table.insert(tmps, tmp)

	return tmp
end

--[[
function Graphics:__MarkAllFree()
	for _, temps in pairs(self.__tempsByCategory) do
		for _, temp in ipairs(temp) do
			temp.free = true
		end
	end
end
]]--

----------------
-- API: BEGIN
----------------

function Graphics:MakeTextureCopies(textures)
	local tmps = {}
	for _, texture in ipairs(textures) do
		local tmp = self:__GetTemp(gl.TextureInfo(texture))
		table.insert(tmps, tmp)
	end

	for i, texture in ipairs(textures) do
		local tmp = tmps[i]
		SB.model.textureManager:Blit(texture, tmp.texture)
	end

	local ret = {}
	for _, tmp in ipairs(tmps) do
		tmp.free = true
		table.insert(ret, tmp.texture)
	end
	return ret
end

-- TODO: Data specific - move someplace else?
function Graphics:MakeMapTextureCopies(mapTextures)
	local wantedCopies = {}
    for i, v in ipairs(mapTextures) do
        table.insert(wantedCopies, v.renderTexture.texture)
    end
    return gfx:MakeTextureCopies(wantedCopies)
end

----------------
-- API: END
----------------
