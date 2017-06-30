SB.Include(Path.Join(SB_VIEW_DIR, "editor.lua"))
SB.Include(Path.Join(SB_VIEW_MAP_DIR, "material_browser.lua"))
SB.Include(Path.Join(SB_VIEW_MAP_DIR, "saved_brushes.lua"))

TerrainEditor = Editor:extends{}
Editor.Register({
    name = "terrainEditor",
    editor = TerrainEditor,
    tab = "Map",
    caption = "Texture",
    tooltip = "Edit textures",
    image = SB_IMG_DIR .. "palette.png",
})

function TerrainEditor:init()
    self.initializing = true
    self:super("init")

    local image_exts = {'.jpg','.bmp','.png','.tga','.dds','.tif'}
    self:AddField(AssetField({
        name = "patternTexture",
        title = "Pattern:",
        rootDir = "brush_patterns/terrain/",
        expand = true,
        itemWidth = 65,
        itemHeight = 65,
        Validate = function(obj, value)
            if not AssetField.Validate(obj, value) then
                return false
            end

            if value == nil then
                return true
            end
            local ext = Path.GetExt(value) or ""
            return table.ifind(image_exts, ext), value
        end
    }))
    self:AddField(MaterialField({
        name = "brushTexture",
        title = "Texture:",
        value = {},
        rootDir = "brush_textures/",
        width = 200,
    }))
    self.savedBrushes = SavedBrushes({
        ctrl = {
            x = 0,
            right = 0,
            --y = "30%",
            --bottom = "45%", -- 100 - 55
            y = 70,
            bottom = "65%", -- 100 - 55
        },
        editor = self,
        name = "mapMaterials",
        GetNewBrush = function()
            local tbl = self:Serialize()
            -- invoke the UI dialog to pick the paint texture
            CallListeners(self.fields["brushTexture"].button.OnClick)

            return {
                opts = tbl,
                caption = nil,
                image = "",
                tooltip = nil,
            }
        end,
        GetBrushImage = function(brush)
            local texturePath = tostring(self.fields["brushTexture"].value.diffuse)
            local texName = brush.image
            if texName == "" then
                texName = BrushDrawer.GetBrushTexture(
                    self.savedBrushes.itemWidth,
                    self.savedBrushes.itemHeight)
            end
            BrushDrawer.UpdateLuaTexture(texName,
                texturePath,
                self.savedBrushes.itemWidth,
                self.savedBrushes.itemHeight,
                self:__GetBrushDrawOpts())

            return texName
        end,
    })

    self.savedDNTSBrushes = SavedBrushes({
        ctrl = {
            x = 0,
            right = 0,
            --y = "30%",
            --bottom = "45%", -- 100 - 55
            y = 70,
            bottom = "65%", -- 100 - 55
        },
        editor = self,
        disableAdd = true,
        disableRemove = true,
        name = "mapDNTS",
        GetNewBrush = function()
            local tbl = self:Serialize()

            -- invoke the UI dialog to pick the paint texture
            CallListeners(self.fields["brushTexture"].button.OnClick)

            return {
                opts = tbl,
                caption = nil,
                image = texturePath,
                tooltip = nil,
            }
        end,
        GetBrushImage = function(brush)
            local texturePath = self.fields["brushTexture"].value.normal
            local texName = brush.image

            -- if there is no texture path set, assume it's one of the existing engine textures
            if texturePath == nil then
                return texName
            end
            texturePath = tostring(texturePath)
            if texName == "" or texName:sub(1, 1) == "$" then
                texName = BrushDrawer.GetBrushTexture(
                    self.savedBrushes.itemWidth,
                    self.savedBrushes.itemHeight)
            end
            BrushDrawer.UpdateLuaTexture(texName,
                texturePath,
                self.savedBrushes.itemWidth,
                self.savedBrushes.itemHeight,
                self:__GetBrushDrawOpts())

            return texName
        end,
    })
    self:AddField(Field({
        name = "dntsIndex",
        value = 0,
    }))
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
                self.savedBrushes:GetControl():Show()
                self.savedDNTSBrushes:GetControl():Hide()
                self:SetInvisibleFields("kernelMode", "splatTexScale", "splatTexMult", "splat-sep", "exclusive", "value")
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
                self.savedBrushes:GetControl():Hide()
                self.savedDNTSBrushes:GetControl():Hide()
                self:SetInvisibleFields("diffuseEnabled", "specularEnabled", "texScale", "texOffsetX", "texOffsetY", "featureFactor", "diffuseColor", "mode", "rotation", "splatTexScale", "splatTexMult", "offset-sep", "splat-sep", "exclusive", "value")
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
                -- if SB.dntsEditor == nil then
                --     SB.dntsEditor = DNTSEditor()
                --     SB.dntsEditor.window.OnHide = {
				-- 		function()
				-- 			obj:SetPressedState(false)
				-- 		end
				-- 	}
                -- end
                -- if SB.dntsEditor.window.hidden then
				-- 	SB.view:SetMainPanel(SB.dntsEditor.window)
                -- end
                self:_EnterState("dnts")
                self.savedBrushes:GetControl():Hide()
                self.savedDNTSBrushes:GetControl():Show()
                self:SetInvisibleFields("kernelMode", "diffuseEnabled", "specularEnabled", "texScale", "texOffsetX", "texOffsetY", "featureFactor", "diffuseColor", "mode", "rotation", "falloffFactor", "offset-sep", "voidFactor", "tex-sep")
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
                self.savedBrushes:GetControl():Hide()
                self.savedDNTSBrushes:GetControl():Hide()
                self:SetInvisibleFields("diffuseEnabled", "specularEnabled", "texScale", "texOffsetX", "texOffsetY", "blendFactor", "featureFactor", "diffuseColor", "mode", "rotation", "kernelMode", "splatTexScale", "splatTexMult", "offset-sep", "splat-sep", "exclusive", "value")
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
            minValue = -1,
            maxValue = 1,
            step = 0.001,
            title = "X:",
            tooltip = "Texture offset X",
        }),
        NumericField({
            name = "texOffsetY",
            value = 0,
            minValue = -1,
            maxValue = 1,
            step = 0.001,
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
        value = 1,
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

    local children = {
        self.btnPaint,
        self.btnFilter,
        self.btnDNTS,
        self.btnVoid,
        --self.patternTextureImages:GetControl(),
        self.savedBrushes:GetControl(),
        self.savedDNTSBrushes:GetControl(),
        ScrollPanel:New {
            x = 0,
            --y = "55%",
            y = "35%",
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
    for i = 0, 3 do
        self:__AddEngineDNTSTexture("$ssmf_splat_normals:" .. tostring(i), i+1)
    end
    self.savedDNTSBrushes:GetControl():Hide()
    self.savedDNTSBrushes:DeselectAll()

    self.initializing = false
end

function TerrainEditor:__AddEngineDNTSTexture(textureName, dntsIndex)
    local tbl = self:Serialize()

    tbl.dntsIndex = dntsIndex

    if gl.GetMapRendering then
        local splatTexScales = {gl.GetMapRendering("splatTexScales")}
        local splatTexMults = {gl.GetMapRendering("splatTexMults")}
        tbl.splatTexScale = splatTexScales[dntsIndex]
        tbl.splatTexMult = splatTexMults[dntsIndex]
    end

    local texturePath = textureName
    self.savedDNTSBrushes:AddBrush({
        opts = tbl,
        caption = "DNTS:" .. tostring(dntsIndex),
        image = textureName,
        tooltip = nil,
    })
end

function TerrainEditor:_GetDNTSIndex()
    return self.fields["dntsIndex"].value
end

function TerrainEditor:__GetBrushDrawOpts()
    return {
        color = self.fields["diffuseColor"].value,
        rotation = self.fields["rotation"].value,
        offset = {
            self.fields["texOffsetX"].value,
            self.fields["texOffsetY"].value,
        },
        scale = self.fields["texScale"].value,
    }
end

function TerrainEditor:OnStartChange(name)
    if name == "splatTexScale" or name == "splatTexMult" then
        SB.commandManager:execute(SetMultipleCommandModeCommand(true))
    end
end

function TerrainEditor:OnEndChange(name)
    if name == "splatTexScale" or name == "splatTexMult" then
        SB.commandManager:execute(SetMultipleCommandModeCommand(false))
    end
end

function TerrainEditor:OnFieldChange(name, value)
    if self.initializing then
        return
    end

    if self.savedBrushes:GetControl().visible then
        local brush = self.savedBrushes:GetSelectedBrush()
        if brush then
            self.savedBrushes:UpdateBrush(brush.brushID, name, value)
            if name == "brushTexture" or name == "texOffsetX" or name == "texOffsetY"
                or name == "diffuseColor" or name == "rotation" or name == "texScale" then
                if name == "brushTexture" then
                    SB.commandManager:execute(CacheTextureCommand(value))
                end

                self.savedBrushes:RefreshBrushImage(brush.brushID)
            end
        end
    elseif self.savedDNTSBrushes:GetControl().visible then
        local brush = self.savedDNTSBrushes:GetSelectedBrush()
        if brush then
            self.savedDNTSBrushes:UpdateBrush(brush.brushID, name, value)
            if name == "brushTexture" then
                --SB.commandManager:execute(CacheTextureCommand(value))
                self.savedDNTSBrushes:RefreshBrushImage(brush.brushID)
            end
        end
    end

    if name == "brushTexture" and self.savedDNTSBrushes:GetControl().visible then
        local dntsIndex = self:_GetDNTSIndex()
        local texture = self.fields["brushTexture"].value.normal
        if dntsIndex and texture then
            Spring.SetMapShadingTexture("$ssmf_splat_normals", texture, dntsIndex)
        end
    elseif name == "splatTexScale" or name == "splatTexMult" then
        local index = self:_GetDNTSIndex()
        local tbl = {gl.GetMapRendering(name .. "s")}
        tbl[index] = value
        local t = {
            [name .. "s"] = tbl,
        }
        local cmd = SetMapRenderingParamsCommand(t)
        SB.commandManager:execute(cmd)
    end
end

function TerrainEditor:_EnterState(paintMode)
    local state = TerrainChangeTextureState(self)
    state.paintMode = paintMode
    SB.stateManager:SetState(state)
end

function TerrainEditor:IsValidTest(state)
    return state:is_A(TerrainChangeTextureState)
end

function TerrainEditor:OnLeaveState(state)
    for _, btn in pairs({self.btnPaint, self.btnFilter, self.btnDNTS, self.btnVoid}) do
        btn:SetPressedState(false)
    end
end

function TerrainEditor:OnEnterState(state)
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
