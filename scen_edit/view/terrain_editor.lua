SCEN_EDIT.Include(SCEN_EDIT_VIEW_DIR .. "editor_view.lua")
SCEN_EDIT.Include(SCEN_EDIT_VIEW_DIR .. "texture_browser.lua")

TerrainEditorView = EditorView:extends{}

function TerrainEditorView:init()
    self:super("init")
	self.paintTexture = {}
    self.brushTexture = {}

	self.textureBrowser = TextureBrowser({
		dir = SCEN_EDIT_IMG_DIR .. "resources/brush_textures/nobiax/",
        width = "100%",
        height = "100%",
    })

    self.textureBrowser.control.OnSelectItem = {
        function(obj, itemIdx, selected)
            if selected and itemIdx > 0 then
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

    self.brushTextureImages = TextureBrowser({
        dir = SCEN_EDIT_IMG_DIR .. "resources/brush_patterns/terrain/good",
        width = "100%",
        height = "100%",
        multiSelect = false,
        iconX = 64,
        iconY = 64,
    })

    self.brushTextureImages.control.OnSelectItem = {
        function(obj, itemIdx, selected)
            if selected and itemIdx > 0 then
                local item = self.brushTextureImages.control.children[itemIdx]
				for k, v in pairs(self.brushTexture) do
					self.brushTexture[k] = nil
				end
				if item.texture ~= nil then
					for k, v in pairs(item.texture) do
						self.brushTexture[k] = v
					end
					SCEN_EDIT.commandManager:execute(CacheTextureCommand(self.brushTexture))

					local currentState = SCEN_EDIT.stateManager:GetCurrentState()
-- 					if currentState.smartPaint then
-- 						table.insert(currentState.textures, {
-- 							texture = SCEN_EDIT.deepcopy(self.brushTexture),
-- 							minHeight = 160, -- math.random(100),
-- 							--minSlope = math.random(),
-- 							minSlope = #currentState.textures* 0.7 + 0,
-- 						})
-- 					end
				end
            end
            -- FIXME: disallow deselection
-- 			if not selected then
-- 				local currentState = SCEN_EDIT.stateManager:GetCurrentState()
-- 				SCEN_EDIT.stateManager:SetState(DefaultState())
-- 			end
        end
    }
--     self.detailTextureImages.OnSelectItem = {
--         function(obj, itemIdx, selected)
--             -- FIXME: shouldn't be using ._dirsNum probably
--             if selected and itemIdx > 0 and itemIdx > obj._dirsNum + 1 then
--                 local item = self.detailTextureImages.items[itemIdx]
--                 self.paintTexture.detail = item
--                 SCEN_EDIT.commandManager:execute(CacheTextureCommand(self.paintTexture))
--                 local currentState = SCEN_EDIT.stateManager:GetCurrentState()
--                 if currentState:is_A(TerrainChangeTextureState) then
--                     currentState.paintTexture = self.paintTexture
--                 end
--             end
--         end
--     }
--     self.detailTextureImages:Select("detailtex2.bmp")

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
                state.paintMode = "paint"
				self:SetInvisibleFields("voidFactor", "kernelMode")
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
                state.paintMode = "void"
				self:SetInvisibleFields("diffuseEnabled", "specularEnabled", "normalEnabled", "texScale", "texOffsetX", "texOffsetY", "blendFactor", "featureFactor", "diffuseColor", "mode", "rotation", "kernelMode")
            end
        },
    })
    self.btnBlur = TabbedPanelButton({
        x = 140,
        y = 0,
        tooltip = "Apply a filter (3)",
        children = {
            TabbedPanelImage({ file = SCEN_EDIT_IMG_DIR .. "terrain_texture.png" }),
            TabbedPanelLabel({ caption = "Filter" }),
        },
        OnClick = {
            function()
				local state = self:EnterState()
                state.paintMode = "blur"
				self:SetInvisibleFields("diffuseEnabled", "specularEnabled", "normalEnabled", "texScale", "texOffsetX", "texOffsetY", "blendFactor", "featureFactor", "diffuseColor", "mode", "rotation")
            end
        },
    })
	-- FIXME: Need to check if HeightMapTexture = 1
	self.btnSmartPaint = TabbedPanelButton({
        x = 210,
        y = 0,
        tooltip = "Smart paint the terrain (3)",
        children = {
            TabbedPanelImage({ file = SCEN_EDIT_IMG_DIR .. "terrain_texture.png" }),
            TabbedPanelLabel({ caption = "Smart paint" }),
        },
        OnClick = {
            function()
				local state = self:EnterState()
                state.paintMode = "smartPaint"
				self:SetInvisibleFields("kernelMode")
				state.textures = {}
            end
        },
    })

    self:AddField(ChoiceField({
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
    }))
    self:AddField(ChoiceField({
        name = "kernelMode",
        items = {
            "blur",
            "bottom_sobel",
            "emboss",
            "left_sobel",
            "outline",
            "right_sobel",
            "sharpen",
            "top sobel",
        },
        title = "Filter:"
    }))

    self:AddControl("tex-sep", {
        Label:New {
            caption = "Texture",
        },
        Line:New {
            x = 50,
            width = self.VALUE_POS,
        }
    })
    self:AddField(GroupField({
        BooleanField({
            name = "diffuseEnabled",
            value = true,
            title = "Diffuse:",
            tooltip = "Diffuse texture",
            width = 140,
        }),
        BooleanField({
            name = "specularEnabled",
            value = true,
            title = "Specular:",
            tooltip = "Specular texture",
            width = 140,
        }),
        BooleanField({
            name = "normalEnabled",
            value = true,
            title = "Normal:",
            tooltip = "Normal texture",
            width = 140,
        })
    }))

    self:AddField(GroupField({
        NumericField({
            name = "size",
            value = 100,
            minValue = 1,
            maxValue = 5000,
            title = "Size:",
            tooltip = "Size of the paint brush",
            width = 150,
        }),
        NumericField({
            name = "rotation",
            value = 0,
            minValue = -360,
            maxValue = 360,
            title = "Rotation:",
            tooltip = "Rotation of the texture",
            width = 150,
        }),
        NumericField({
            name = "texScale",
            value = 2,
            minValue = 0.01,
            step = 0.05,
            title = "Scale:",
            tooltip = "Texture sampling rate (larger number means higher frequency)",
            width = 150,
        })
    }))
    self:AddControl("offset-sep", {
        Label:New {
            caption = "Offset",
        },
        Line:New {
            x = 50,
            width = self.VALUE_POS,
        }
    })
    self:AddField(GroupField({
        NumericField({
            name = "texOffsetX",
            value = 0,
            minValue = -1024,
            maxValue = 1024,
            title = "X:",
            tooltip = "Texture offset X",
        }),
        NumericField({
            name = "texOffsetY",
            value = 0,
            minValue = -1024,
            maxValue = 1024,
            title = "Y:",
            tooltip = "Texture offset Y",
        })
    }))
--     self:AddField(NumericField({
--         name = "detailTexScale",
--         value = 0.2,
--         minValue = 0.01,
--         maxValue = 1,
--         title = "Detail texture scale:",
--         tooltip = "Detail texture sampling rate (larger number means higher frequency)",
--     })
    self:AddControl("blending-sep", {
        Label:New {
            caption = "Blending",
        },
        Line:New {
            x = 50,
            width = self.VALUE_POS,
        }
    })
    self:AddField(GroupField({
        NumericField({
            name = "blendFactor",
            value = 1,
            minValue = 0.0,
            maxValue = 1,
            title = "Blend:",
            tooltip = "Proportion of texture to be applied",
            width = 150,
        }),
        NumericField({
            name = "falloffFactor",
            value = 0.3,
            minValue = 0.0,
            maxValue = 1,
            title = "Falloff:",
            tooltip = "Texture painting fade out (1 means crisp)",
            width = 150,
        }),
        NumericField({
            name = "featureFactor",
            value = 1,
            minValue = 0.0,
            maxValue = 1,
            title = "Feature:",
            tooltip = "Feature filtering (1 means no filter filtering)",
            width = 150,
        })
    }))

	self:AddField(NumericField({
        name = "voidFactor",
        value = 0,
        minValue = 0.0,
        maxValue = 1,
        title = "Transparency:",
        tooltip = "The greater the value, the more transparent it will be.",
    }))

    self:AddField(ColorField({
        name = "diffuseColor",
        title = "Color: ",
        value = {1,1,1,1},
    }))
    self:Update("size")
    self:Update("mode")
    self:Update("kernelMode")
    self:Update("diffuseColor")


	local children = {
		self.btnPaint,
		self.btnVoid,
		self.btnSmartPaint,
        self.btnBlur,
		ScrollPanel:New {
			x = 0,
			right = 0,
			y = 70,
			height = "30%",
			padding = {0, 0, 0, 0},
			children = {
				self.textureBrowser.control,
			}
		},
        ScrollPanel:New {
			x = 0,
			right = 0,
			y = "38%",
			height = "20%",
			padding = {0, 0, 0, 0},
			children = {
				self.brushTextureImages.control,
			}
		},
		ScrollPanel:New {
			x = 0,
			y = "55%",
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
    currentState.brushTexture = self.brushTexture
	return currentState
end

function TerrainEditorView:Select(indx)
    self.textureBrowser:Select(indx)
end

function TerrainEditorView:IsValidTest(state)
    return state:is_A(TerrainChangeTextureState)
end
