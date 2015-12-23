SCEN_EDIT.Include(SCEN_EDIT_VIEW_DIR .. "map_editor_view.lua")
TerrainSettingsView = MapEditorView:extends{}

function TerrainSettingsView:init()
    self:super("init")

    self.images = ImageListView:New {
        padding = {0, 0, 0, 0},
        dir = SCEN_EDIT_IMG_DIR .. "resources/skyboxes",
        width = "100%",
        height = "100%",
    }
    -- FIXME: implement a button for entering the mode instead of image selection
    self.images.OnSelectItem = {
        function(obj, itemIdx, selected)
			if selected and itemIdx > 0 and itemIdx > obj._dirsNum + 1 then
				SCEN_EDIT.delayGL(function()
					local item = self.images.items[itemIdx]
-- 					Spring.Echo(GL.TEXTURE_CUBE_MAP, GL.TEXTURE_2D)
-- 					
-- 					local tex = gl.CreateTexture(texInfo.xsize, texInfo.ysize, {
-- -- 						target = 0x8513,
-- 						min_filter = GL.LINEAR,
-- 						mag_filter = GL.LINEAR,
-- 						fbo = true,
-- 					})
-- -- 					gl.Texture(item)
-- 					Spring.Echo(texInfo.xsize, texInfo.ysize, item)
-- 					SCEN_EDIT.model.textureManager:Blit(item, tex)
					local texInfo = gl.TextureInfo(item)
					Spring.SetSkyBoxTexture(item)
				end)
			end

        end
    }
	
	
    self.images2 = ImageListView:New {
        padding = {0, 0, 0, 0},
        dir = SCEN_EDIT_IMG_DIR .. "resources/brush_patterns/detail",
        width = "100%",
        height = "100%",
    }
    -- FIXME: implement a button for entering the mode instead of image selection
    self.images2.OnSelectItem = {
        function(obj, itemIdx, selected)
			if selected and itemIdx > 0 and itemIdx > obj._dirsNum + 1 then
				SCEN_EDIT.delayGL(function()
					local item = self.images2.items[itemIdx]
-- 					Spring.Echo(GL.TEXTURE_CUBE_MAP, GL.TEXTURE_2D)
-- 					
-- 					local tex = gl.CreateTexture(texInfo.xsize, texInfo.ysize, {
-- -- 						target = 0x8513,
-- 						min_filter = GL.LINEAR,
-- 						mag_filter = GL.LINEAR,
-- 						fbo = true,
-- 					})
-- -- 					gl.Texture(item)
-- 					Spring.Echo(texInfo.xsize, texInfo.ysize, item)
-- 					SCEN_EDIT.model.textureManager:Blit(item, tex)
					local texInfo = gl.TextureInfo(item)
					gl.DeleteTexture(item)
					gl.Texture(item)
					Spring.SetMapShadingTexture("detail", item)
				end)
			end

        end
    }

    local children = {
		ScrollPanel:New {
			x = 0, 
			right = 0,
			y = 70, 
			height = "35%",
			children = { 
				self.images,
			}
		},
		ScrollPanel:New {
			x = 0, 
			right = 0,
			y = "50%", 
			height = "35%",
			children = { 
				self.images2,
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
-- 	self.images:Hide()
-- 	self.images:Select("circle.png")
end
