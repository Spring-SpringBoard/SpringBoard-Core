SCEN_EDIT.Include(SCEN_EDIT_VIEW_DIR .. "folder_view.lua")

TextureBrowser = FolderView:extends{}

function TextureBrowser:init(tbl)
	self:super("init", tbl)
end

function TextureBrowser:ScanDirStarted()
	self.textures = {} -- file base -> texture mapping
	self.textureOrder = {}
	self.blacklist = {}
	-- read blacklist
	
	pcall(function()
		local blacklist = loadstring(VFS.LoadFile(self.dir .. "blacklist.lua"))()
		for _, line in pairs(blacklist) do 
			self.blacklist[line:lower():trim()] = true
		end
	end)
end

function TextureBrowser:PopulateItems()
	for _, name in pairs(self.textureOrder) do
		local texture = self.textures[name]
		local tooltip = name
		if texture.diffuse then
			tooltip = tooltip .. "\nDiffuse: \255\0\255\0✔\b"
		else
			tooltip = tooltip .. "\nDiffuse: \255\255\0\0✘\b"
		end
		for texType, _ in pairs(SCEN_EDIT.model.textureManager.shadingTextures) do
			if texture[texType] then
				tooltip = tooltip .. "\n" .. texType:sub(1,1):upper() .. texType:sub(2) .. ": \255\0\255\0✔\b"
			else
				tooltip = tooltip .. "\n" .. texType:sub(1,1):upper() .. texType:sub(2) .. ": \255\255\0\0✘\b"
			end
		end
        local texturePath = ':clr' .. self.iconX .. ',' .. self.iconY .. ':' .. texture.diffuse
		local item = self:AddItem(name, texturePath or "", tooltip)
		item.texture = texture
	end
end

function TextureBrowser:FilterFile(file)
	local ext = file:GetExt()
	if file:ends("_height" .. ext) or file:ends("_glow" .. ext) or file:ends("_emissive" .. ext) then
		return
	end

	local tType, base
	if file:ends("_diffuse" .. ext) then
		base = file:gsub("_diffuse" .. ext, "")
		tType = "diffuse"
	else
		for texType, _ in pairs(SCEN_EDIT.model.textureManager.shadingTextures) do
			local fileEnd = "_" .. texType .. ext
			if file:ends(fileEnd) then
				base = file:gsub(fileEnd, "")
				tType = texType
				break
			end
		end
	end
	if not base then
		base = file:gsub(ext, "")
		tType = "diffuse"
	end
	
	if base then
		base = self:ExtractFileName(base)
		if self.blacklist[base:lower()] then
			return
		end
		if not self.textures[base] then
			self.textures[base] = {}
			table.insert(self.textureOrder, base)
		end
		self.textures[base][tType] = file
		return true
	end
end