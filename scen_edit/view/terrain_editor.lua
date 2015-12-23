SCEN_EDIT.Include(SCEN_EDIT_VIEW_DIR .. "map_editor_view.lua")
SCEN_EDIT.Include(SCEN_EDIT_VIEW_DIR .. "folder_view.lua")

TerrainEditorView = MapEditorView:extends{}

function TerrainEditorView:init()
    self:super("init")
	self.paintTexture = {}

	self.textureBrowser = TextureBrowser({
		dir = SCEN_EDIT_IMG_DIR .. "resources/brush_textures/nobiax/",
        width = "100%",
        height = "100%",
    })

    self.textureBrowser.control.OnSelectItem = {
        function(obj, itemIdx, selected)
            if selected and itemIdx > 0 then
-- 				Spring.Echo("new state")
                local item = self.textureBrowser.control.children[itemIdx]
				for k, v in pairs(self.paintTexture) do
					self.paintTexture[k] = nil
				end
				if item.texture ~= nil then
					for k, v in pairs(item.texture) do
						self.paintTexture[k] = v
					end
					SCEN_EDIT.commandManager:execute(CacheTextureCommand(self.paintTexture))
					
					local currentState = SCEN_EDIT.stateManager:GetCurrentState()
					if currentState.smartPaint then
						Spring.Echo("BLA!")
						table.insert(currentState.textures, {
							texture = SCEN_EDIT.deepcopy(self.paintTexture),
							minHeight = 160, -- math.random(100),
							--minSlope = math.random(),
							minSlope = #currentState.textures* 0.7 + 0,
						})
					end
				end
            end
            -- FIXME: disallow deselection
-- 			if not selected then
-- 				local currentState = SCEN_EDIT.stateManager:GetCurrentState()
-- 				SCEN_EDIT.stateManager:SetState(DefaultState())
-- 			end
        end
    }

    self.detailTextureImages = ImageListView:New {
        dir = SCEN_EDIT_IMG_DIR .. "resources/brush_patterns/detail/",
        width = "100%",
        height = "100%",
        multiSelect = false,
        iconX = 48,
        iconY = 48,
    }
    self.detailTextureImages.OnSelectItem = {
        function(obj, itemIdx, selected)
            -- FIXME: shouldn't be using ._dirsNum probably
            if selected and itemIdx > 0 and itemIdx > obj._dirsNum + 1 then
                local item = self.detailTextureImages.items[itemIdx]
                self.paintTexture.detail = item
                SCEN_EDIT.commandManager:execute(CacheTextureCommand(self.paintTexture))
                local currentState = SCEN_EDIT.stateManager:GetCurrentState()
                if currentState:is_A(TerrainChangeTextureState) then
                    currentState.paintTexture = self.paintTexture
                end
            end
        end
    }
    self.detailTextureImages:Select("detailtex2.bmp")

--     self.tabPanel = Chili.TabPanel:New {
--         x = 0, 
--         right = 0,
--         y = 70, 
--         height = "40%",
--         padding = {0, 0, 0, 0},
--         tabs = { {
--                 name = "Brush",
--                 children = {
--                     ScrollPanel:New {
--                         x = 1,
--                         right = 1,
--                         y = 0,
--                         bottom = 0,
--                         children = { 
--                             self.textureBrowser.control,
--                         }
--                     },
--                 },
--             }, {
--                 name = "Detail", 
--                 children = { 
--                     ScrollPanel:New {
--                         x = 1,
--                         right = 1,
--                         y = 0,
--                         bottom = 0,
--                         children = { 
--                             self.detailTextureImages 
--                         },
--                     },
--                 },
--             }
--         },
--     }
	
	self.btnPaint = TabbedPanelButton({
        x = 0,
        y = 0,
        tooltip = "Paint the terrain (1)",
        children = {
            TabbedPanelImage({ file = SCEN_EDIT_IMG_DIR .. "terrain_texture.png" }),
            TabbedPanelLabel({ caption = "Paint" }),
        },
        OnClick = {
            function()
				local state = self:EnterState()
				state.void = false
				state.smartPaint = false
				self:SetInvisibleFields()
            end
        },
    })
    self.btnVoid = TabbedPanelButton({
        x = 70,
        y = 0,
        tooltip = "Make the terrain transparent (2)",
        children = {
            TabbedPanelImage({ file = SCEN_EDIT_IMG_DIR .. "terrain_texture.png" }),
            TabbedPanelLabel({ caption = "Void" }),
        },
        OnClick = {
            function()
				local state = self:EnterState()
				state.void = true
				state.smartPaint = false
				self:SetInvisibleFields("diffuseEnabled", "specularEnabled", "normalEnabled", "texScale", "texOffsetX", "texOffsetY", "blendFactor", "featureFactor", "diffuseColor", "mode", "rotation")
            end
        },
    })
	-- FIXME: Need to check if HeightMapTexture = 1 
	self.btnSmartPaint = TabbedPanelButton({
        x = 140,
        y = 0,
        tooltip = "Smart paint the terrain (3)",
        children = {
            TabbedPanelImage({ file = SCEN_EDIT_IMG_DIR .. "terrain_texture.png" }),
            TabbedPanelLabel({ caption = "Smart paint" }),
        },
        OnClick = {
            function()
				local state = self:EnterState()
				state.void = false
				state.smartPaint = true
				self:SetInvisibleFields()
				state.textures = {}
            end
        },
    })

    self:AddChoiceProperty({
        name = "mode",
        items = {
            "Normal",
            "Darken",
            "Lighten",
            "SoftLight",
            "HardLight",
            "Luminance",
            "Multiply",
            "Premultiplied",
            "Overlay",
            "Screen",
            "Add",
            "Subtract",
            "Difference",
            "InverseDifference",
            "Exclusion",
            "Color",
            "ColorBurn",
            "ColorDodge",
        },
        title = "Mode:"
    })
	self:AddBooleanProperty({
        name = "diffuseEnabled", 
        value = true,
        title = "Diffuse:",
        tooltip = "Diffuse texture",
    })
	self:AddBooleanProperty({
        name = "specularEnabled", 
        value = true,
        title = "Specular:",
        tooltip = "Specular texture",
    })
	self:AddBooleanProperty({
        name = "normalEnabled", 
        value = true,
        title = "Normal:",
        tooltip = "Normal texture",
    })
    self:AddNumericProperty({
        name = "size", 
        value = 100, 
        minValue = 10, 
        maxValue = 5000, 
        title = "Size:",
        tooltip = "Size of the paint brush",
    })
    self:AddNumericProperty({
        name = "rotation",
        value = 0,
        minValue = 0,
        maxValue = 360,
        title = "Texture rotation:",
        tooltip = "Rotation of the texture",
    })
    self:AddNumericProperty({
        name = "texScale",
        value = 2,
        minValue = 0.1,
        maxValue = 50,
        title = "Texture scale:",
        tooltip = "Texture sampling rate (larger number means higher frequency)",
    })
    self:AddNumericProperty({
        name = "texOffsetX",
        value = 0,
        minValue = -1024,
        maxValue = 1024,
        title = "Texture offset X:",
        tooltip = "Texture offset X",
    })
    self:AddNumericProperty({
        name = "texOffsetY",
        value = 0,
        minValue = -1024,
        maxValue = 1024,
        title = "Texture offset Y:",
        tooltip = "Texture offset Y",
    })
--     self:AddNumericProperty({
--         name = "detailTexScale",
--         value = 0.2,
--         minValue = 0.01,
--         maxValue = 1,
--         title = "Detail texture scale:",
--         tooltip = "Detail texture sampling rate (larger number means higher frequency)",
--     })
    self:AddNumericProperty({
        name = "blendFactor",
        value = 1,
        minValue = 0.0,
        maxValue = 1,
        title = "Blend:",
        tooltip = "Proportion of texture to be applied",
    })
    self:AddNumericProperty({
        name = "falloffFactor",
        value = 0.3,
        minValue = 0.0,
        maxValue = 1,
        title = "Falloff:",
        tooltip = "Texture painting fade out (1 means crisp)",
    })
    self:AddNumericProperty({
        name = "featureFactor",
        value = 1,
        minValue = 0.0,
        maxValue = 1,
        title = "Feature:",
        tooltip = "Feature filtering (1 means no filter filtering)",
    })
	
	self:AddNumericProperty({
        name = "voidFactor",
        value = 0,
        minValue = 0.0,
        maxValue = 1,
        title = "Transparency:",
        tooltip = "The greater the value, the more transparent it will be.",
    })
	
    self:AddColorbarsProperty({
        name = "diffuseColor",
        title = "Color: ",
        value = {1,1,1,1},
    })
    self:UpdateNumericField("size")
    self:UpdateChoiceField("mode")
    self:UpdateColorbarsField("diffuseColor")


	local children = {
		self.btnPaint,
		self.btnVoid,
		self.btnSmartPaint,
		ScrollPanel:New {
			x = 0, 
			right = 0,
			y = 70, 
			height = "35%",
			padding = {0, 0, 0, 0},
			children = { 
				self.textureBrowser.control,
			}
		},
		ScrollPanel:New {
			x = 0,
			y = "45%",
			bottom = 30,
			right = 0,
			borderColor = {0,0,0,0},
			horizontalScrollbar = false,
			children = { self.stackPanel },
		},
	}
	self:Finalize(children)
end

function TerrainEditorView:EnterState()
	local currentState = SCEN_EDIT.stateManager:GetCurrentState()
	if not currentState:is_A(TerrainChangeTextureState) then
		currentState = TerrainChangeTextureState(self)
		SCEN_EDIT.stateManager:SetState(currentState)
	end
	currentState.paintTexture = self.paintTexture
	return currentState
end

function TerrainEditorView:Select(indx)
    self.textureBrowser:Select(indx)
end

function TerrainEditorView:IsValidTest(state)
    return state:is_A(TerrainChangeTextureState)
end

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
		local item = self:AddItem(name, texture.diffuse or "", tooltip)
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