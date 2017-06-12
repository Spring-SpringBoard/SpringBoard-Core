SB.Include(Path.Join(SB_VIEW_DIR, "editor_view.lua"))
SB.Include(Path.Join(SB_VIEW_MAP_DIR, "texture_browser.lua"))
SB.Include(Path.Join(SB_VIEW_MAP_DIR, "saved_brushes.lua"))

TerrainEditorView = EditorView:extends{}

function TerrainEditorView:init()
    self.initializing = true
    self:super("init")
    self:AddField(TextureField({
        name = "brushTexture",
        title = "Texture:",
        value = {},
        rootDir = "brush_textures/",
        width = 200,
    }))
    self:AddField(Field({
        name = "patternTexture",
        Update = function(...)
            local path = self.fields["patternTexture"].value
            local item = self.patternTextureImages:GetSelectedItems()[1]
            if not item or path ~= item then
                if path then
                    self.patternTextureImages:SelectAsset(path)
                else
                    self.patternTextureImages:DeselectAll()
                end
            end
        end
    }))

    self.savedBrushes = SavedBrushes({
        ctrl = {
            width = "100%",
            height = "100%",
            iconX = 64,
            iconY = 64,
            -- FIXME: Shouldn't need to set minWidth
            minWidth = 400,
        },
        editor = self,
        GetNewBrush = function()
            local tbl = self:Serialize()

            local diffuse = tbl.brushTexture.diffuse
            local texturePath = ':clr' .. self.savedBrushes.iconX .. ',' .. self.savedBrushes.iconY .. ':' .. tostring(diffuse)

            -- invoke the UI dialog to pick the paint texture
            CallListeners(self.fields["brushTexture"].button.OnClick)

            return {
                opts = tbl,
                caption = nil,
                image = texturePath,
                tooltip = nil,
            }
        end,
    })

    self.patternTextureImages = AssetView({
        ctrl = {
            width = "100%",
            height = "100%",
            multiSelect = false,
            iconX = 65,
            iconY = 65,
        },
        rootDir = "brush_patterns/terrain/",
        OnSelectItem = {
            function(item, selected)
                self:Set("patternTexture", nil)
                if selected then
                    self:Set("patternTexture", item.path)
                end
            end
        },
    })

    self.btnPaint = TabbedPanelButton({
        x = 0,
        y = 0,
        tooltip = "Paint the terrain",
        children = {
            TabbedPanelImage({ file = SB_IMG_DIR .. "large-paint-brush.png" }),
            TabbedPanelLabel({ caption = "Paint" }),
        },
        OnClick = {
            function()
                self:_EnterState("paint")
                self:SetInvisibleFields("kernelMode", "dnts", "splatTexScale", "splatTexMult", "splat-sep", "exclusive", "value")
            end
        },
    })
    self.btnFilter = TabbedPanelButton({
        x = 70,
        y = 0,
        tooltip = "Apply a filter",
        children = {
            TabbedPanelImage({ file = SB_IMG_DIR .. "filter-brush.png" }),
            TabbedPanelLabel({ caption = "Filter" }),
        },
        OnClick = {
            function()
                self:_EnterState("blur")
                self:SetInvisibleFields("diffuseEnabled", "specularEnabled", "normalEnabled", "texScale", "texOffsetX", "texOffsetY", "featureFactor", "diffuseColor", "mode", "rotation", "dnts", "splatTexScale", "splatTexMult", "offset-sep", "splat-sep", "exclusive", "value")
            end
        },
    })
    self.btnDNTS = TabbedPanelButton({
        x = 140,
        y = 0,
        tooltip = "DNTS textures",
        children = {
            TabbedPanelImage({ file = SB_IMG_DIR .. "paint-brush.png" }),
            TabbedPanelLabel({ caption = "DNTS" }),
        },
        OnClick = {
            function(obj)
                -- if SB.dntsEditorView == nil then
                --     SB.dntsEditorView = DNTSEditorView()
                --     SB.dntsEditorView.window.OnHide = {
				-- 		function()
				-- 			obj:SetPressedState(false)
				-- 		end
				-- 	}
                -- end
                -- if SB.dntsEditorView.window.hidden then
				-- 	SB.view:SetMainPanel(SB.dntsEditorView.window)
                -- end
                self:_EnterState("dnts")
                self:SetInvisibleFields("kernelMode", "diffuseEnabled", "specularEnabled", "normalEnabled", "texScale", "texOffsetX", "texOffsetY", "featureFactor", "diffuseColor", "mode", "rotation", "falloffFactor", "offset-sep", "voidFactor", "tex-sep")
            end
        },
    })
    self.btnVoid = TabbedPanelButton({
        x = 210,
        y = 0,
        tooltip = "Make the terrain transparent",
        children = {
            TabbedPanelImage({ file = SB_IMG_DIR .. "large-paint-brush.png" }),
            TabbedPanelLabel({ caption = "Void" }),
        },
        OnClick = {
            function()
                self:_EnterState("void")
                self:SetInvisibleFields("diffuseEnabled", "specularEnabled", "normalEnabled", "texScale", "texOffsetX", "texOffsetY", "blendFactor", "featureFactor", "diffuseColor", "mode", "rotation", "kernelMode", "dnts", "splatTexScale", "splatTexMult", "offset-sep", "splat-sep", "exclusive", "value")
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
    self:AddField(ChoiceField({
        name = "dnts",
        items = {
            "1",
            "2",
            "3",
            "4",
        },
        title = "DNTS:"
    }))
    self:AddField(BooleanField({
        name = "exclusive",
        title = "Exclusive: ",
        value = false,
    }))

    self:AddControl("tex-sep", {
        Label:New {
            caption = "Texture",
        },
        Line:New {
            x = 55,
            y = 4,
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
            y = 4,
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
    self:AddControl("blending-sep", {
        Label:New {
            caption = "Blending",
        },
        Line:New {
            x = 50,
            y = 4,
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
        name = "value",
        value = 1,
        minValue = 0.0,
        maxValue = 1,
        title = "Value:",
        tooltip = "Goal value to be set for DNTS textures when painting.",
    }))

    self:AddField(NumericField({
        name = "voidFactor",
        value = 0,
        minValue = 0.0,
        maxValue = 1,
        title = "Transparency:",
        tooltip = "The greater the value, the more transparent it will be.",
    }))

    self:AddControl("splat-sep", {
        Label:New {
            caption = "Splat",
        },
        Line:New {
            x = 55,
            y = 4,
            width = self.VALUE_POS,
        }
    })
    self:AddField(GroupField({
        NumericField({
            name = "splatTexScale",
            value = 1,
            step = 0.000001,
            decimals = 6,
            title = "Scale:",
            tooltip = "Splat texture multiplier",
            width = 150,
        }),
        NumericField({
            name = "splatTexMult",
            value = 0.5,
            step = 0.01,
            title = "Mult:",
            tooltip = "Splat texture multiplier",
            width = 150,
        }),
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
    self:_UpdateDNTS()

    local children = {
        self.btnPaint,
        self.btnFilter,
        self.btnDNTS,
        self.btnVoid,
        ScrollPanel:New {
            x = 0,
            right = 0,
            y = 70,
            bottom = "70%", -- 100 - 30
            padding = {0, 0, 0, 0},
            borderColor = {0,0,0,0},
            children = {
                self.patternTextureImages.control,
            }
        },
        ScrollPanel:New {
            x = 0,
            right = 0,
            y = "30%",
            bottom = "45%", -- 100 - 55
            padding = {0, 0, 0, 0},
            borderColor = {0,0,0,0},
            children = {
                self.savedBrushes.control,
            }
        },
        ScrollPanel:New {
            x = 0,
            y = "55%",
            bottom = 30,
            right = 0,
            borderColor = {0,0,0,0},
            horizontalScrollbar = false,
            children = {
                self.stackPanel
            },
        },
    }
    self:Finalize(children)
    self.initializing = false
end

function TerrainEditorView:_UpdateDNTS()
    if not gl.GetMapRendering then
        return
    end

    local splatTexScales = {gl.GetMapRendering("splatTexScales")}
    local splatTexMults = {gl.GetMapRendering("splatTexMults")}
    local index = tonumber(self.fields["dnts"].value)
    self:Set("splatTexScale", splatTexScales[index])
    self:Set("splatTexMult", splatTexMults[index])
end

function TerrainEditorView:OnStartChange(name)
    if name == "splatTexScale" or name == "splatTexMult" then
        SB.commandManager:execute(SetMultipleCommandModeCommand(true))
    end
end

function TerrainEditorView:OnEndChange(name)
    if name == "splatTexScale" or name == "splatTexMult" then
        SB.commandManager:execute(SetMultipleCommandModeCommand(false))
    end
end

function TerrainEditorView:OnFieldChange(name, value)
    local brush = self.savedBrushes:GetSelectedBrush()
    if brush then
        self.savedBrushes:UpdateBrush(brush.brushID, name, value)
        if name == "brushTexture" then
            SB.commandManager:execute(CacheTextureCommand(value))

            local diffuse = value.diffuse
            local texturePath = ':clr' .. self.savedBrushes.iconX .. ',' .. self.savedBrushes.iconY .. ':' .. tostring(diffuse)

            self.savedBrushes:UpdateBrushImage(brush.brushID, texturePath)
        end
    end

    if self.initializing then
        return
    end

    if name == "dnts" then
        self:_UpdateDNTS()
    elseif name == "splatTexScale" or name == "splatTexMult" then
        local index = tonumber(self.fields["dnts"].value)
        local tbl = {gl.GetMapRendering(name .. "s")}
        tbl[index] = value
        local t = {
            [name .. "s"] = tbl,
        }
        local cmd = SetMapRenderingParamsCommand(t)
        SB.commandManager:execute(cmd)
    end
end

function TerrainEditorView:_EnterState(paintMode)
    local state = TerrainChangeTextureState(self)
    state.paintMode = paintMode
    SB.stateManager:SetState(state)
end

function TerrainEditorView:IsValidTest(state)
    return state:is_A(TerrainChangeTextureState)
end

function TerrainEditorView:OnLeaveState(state)
    for _, btn in pairs({self.btnPaint, self.btnFilter, self.btnDNTS, self.btnVoid}) do
        btn:SetPressedState(false)
    end
end

function TerrainEditorView:OnEnterState(state)
    if state.paintMode == "paint" then
        self.btnPaint:SetPressedState(true)
    elseif state.paintMode == "blur" then
        self.btnFilter:SetPressedState(true)
    elseif state.paintMode == "dnts" then
        self.btnDNTS:SetPressedState(true)
    elseif state.paintMode == "void" then
        self.btnVoid:SetPressedState(true)
    end
end
