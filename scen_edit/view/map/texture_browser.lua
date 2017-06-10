SB.Include(Path.Join(SB_VIEW_DIR, "asset_view.lua"))

TextureBrowser = AssetView:extends{}

function TextureBrowser:init(tbl)
	self:super("init", tbl)
end

function TextureBrowser:ScanDirStarted()
	self.textures = {} -- file base -> texture mapping
	self.textureOrder = {}
end

function TextureBrowser:PopulateItems()
	for _, name in pairs(self.textureOrder) do
		local texture = self.textures[name]
		local tooltip = name
		if texture.diffuse then
			tooltip = tooltip .. "\nDiffuse: \255\0\255\0OK\b"
		else
			tooltip = tooltip .. "\nDiffuse: \255\255\0\0NO\b"
		end
		for name, texDef in pairs(SB.model.textureManager:GetShadingTextureDefs()) do
			if texDef.enabled then
				if texture[name] then
					tooltip = tooltip .. "\n" .. name:sub(1,1):upper() .. name:sub(2) .. ": \255\0\255\0OK\b"
				else
					tooltip = tooltip .. "\n" .. name:sub(1,1):upper() .. name:sub(2) .. ": \255\255\0\0NO\b"
				end
			end
		end
        local texturePath = ':clr' .. self.iconX .. ',' .. self.iconY .. ':' .. tostring(texture.diffuse)
		local item = self:AddItem(name, texturePath or "", tooltip)
		item.texture = texture
	end
end

function TextureBrowser:FilterFile(filePath)
	local ext = filePath:GetExt()
	if filePath:ends("_height" .. ext) or filePath:ends("_glow" .. ext) or filePath:ends("_emissive" .. ext) then
		return
	end

	local tType, base
	if filePath:ends("_diffuse" .. ext) then
		base = filePath:gsub("_diffuse" .. ext, "")
		tType = "diffuse"
	else
		for name, texDef in pairs(SB.model.textureManager:GetShadingTextureDefs()) do
			local fileEnd = "_" .. name .. ext
			if filePath:ends(fileEnd) then
				if not texDef.enabled then
					return
				end
				base = filePath:gsub(fileEnd, "")
				tType = name
				break
			end
		end
	end
	if not base then
		base = filePath:gsub(ext, "")
		tType = "diffuse"
	end

	base = Path.ExtractFileName(base)
	if not self.textures[base] then
		self.textures[base] = {}
		table.insert(self.textureOrder, base)
	end
	self.textures[base][tType] = filePath
	return true
end
