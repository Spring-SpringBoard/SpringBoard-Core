SB.Include(Path.Join(SB.DIRS.SRC, 'view/asset_view.lua'))

MaterialBrowser = AssetView:extends{}

function MaterialBrowser:init(tbl)
    if not self.textures then
        self.textures = {}
        for texName, _ in pairs(SB.model.textureManager.materialTextures) do
            table.insert(self.textures, texName)
        end
    end
    self:super("init", tbl)
end

function MaterialBrowser:ScanDirStarted()
    self._textureFiles = {} -- file base -> texture mapping
    self._textureOrder = {}
end

function MaterialBrowser:PopulateItems()
    for _, name in pairs(self._textureOrder) do
        local texture = self._textureFiles[name]
        local tooltip = name
        for _, texName in pairs(self.textures) do
            local texDef = SB.model.textureManager.materialTextures[texName]
            if texDef.enabled then
                if texture[texName] then
                    tooltip = tooltip .. "\n" .. texName:sub(1,1):upper() .. texName:sub(2) .. ": \255\0\255\0OK\b"
                else
                    tooltip = tooltip .. "\n" .. texName:sub(1,1):upper() .. texName:sub(2) .. ": \255\255\0\0NO\b"
                end
            end
        end
        local texturePath = ':clr' .. self.itemWidth .. ',' .. self.itemHeight .. ':' .. tostring(texture.diffuse)
        local item = self:AddItem(name, texturePath or "", tooltip)
        item.texture = texture
    end
end

function MaterialBrowser:FilterFile(filePath)
    local ext = filePath:GetExt()

    local tType, base
    for _, texName in pairs(self.textures) do
        local texDef = SB.model.textureManager.materialTextures[texName]
        local fileEnd = texDef.suffix .. ext
        if String.Ends(filePath, fileEnd) then
            if not texDef.enabled then
                return
            end
            base = filePath:gsub(fileEnd, "")
            tType = texName
            break
        end
    end
    if not base then
        return
    end

    base = Path.ExtractFileName(base)
    if not self._textureFiles[base] then
        self._textureFiles[base] = {}
        table.insert(self._textureOrder, base)
    end
    self._textureFiles[base][tType] = filePath
    return true
end
