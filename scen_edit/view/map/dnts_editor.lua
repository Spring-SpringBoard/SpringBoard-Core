-- UNUSED (dnts is in texture_editor.lua)

SB.Include(Path.Join(SB.DIRS.SRC, 'view/editor.lua'))
SB.Include(Path.Join(SB.DIRS.SRC, 'view/map/material_browser.lua'))
SB.Include(Path.Join(SB.DIRS.SRC, 'view/map/saved_brushes.lua'))

DNTSEditor = Editor:extends{}

function DNTSEditor:init()
    self:super("init")
    self:AddField(MaterialField({
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

    self.btnDNTS = TabbedPanelButton({
        x = 140,
        y = 0,
        tooltip = "DNTS textures",
        children = {
            TabbedPanelImage({ file = Path.Join(SB.DIRS.IMG, 'paint-brush.png') }),
            TabbedPanelLabel({ caption = "DNTS" }),
        },
        OnClick = {
            function()
                SB.stateManager:SetState(TerrainChangeDNTSState(self))
            end
        },
    })

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

    self:AddField(NumericField({
        name = "size",
        value = 100,
        minValue = 1,
        maxValue = 5000,
        title = "Size:",
        tooltip = "Size of the paint brush",
        width = 150,
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
            name = "strength",
            value = 1,
            minValue = 0.0,
            maxValue = 1,
            title = "Blend:",
            tooltip = "Proportion of texture to be applied",
            width = 150,
        }),
        NumericField({
            name = "dntsValue",
            value = 0.3,
            minValue = 0.0,
            maxValue = 1,
            title = "Strength:",
            tooltip = "DNTS strength",
            width = 150,
        }),
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
    self:_UpdateDNTS()

    local children = {
        self.btnDNTS,
        ScrollPanel:New {
            x = 0,
            right = 0,
            y = 70,
            bottom = "70%", -- 100 - 30
            padding = {0, 0, 0, 0},
            borderColor = {0,0,0,0},
            children = {
                self.patternTextureImages:GetControl(),
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
                self.savedBrushes:GetControl(),
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
end

function DNTSEditor:_UpdateDNTS()
    if not gl.GetMapRendering then
        return
    end

    local splatTexScales = {gl.GetMapRendering("splatTexScales")}
    local splatTexMults = {gl.GetMapRendering("splatTexMults")}
    local index = tonumber(self.fields["dnts"].value)
    self:Set("splatTexScale", splatTexScales[index])
    self:Set("splatTexMult", splatTexMults[index])
end

function DNTSEditor:OnStartChange(name)
    if name == "splatTexScale" or name == "splatTexMult" then
        SB.commandManager:execute(SetMultipleCommandModeCommand(true))
    end
end

function DNTSEditor:OnEndChange(name)
    if name == "splatTexScale" or name == "splatTexMult" then
        SB.commandManager:execute(SetMultipleCommandModeCommand(false))
    end
end

function DNTSEditor:OnFieldChange(name, value)
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

function DNTSEditor:IsValidState(state)
    return state:is_A(TerrainChangeTextureState)
end

function DNTSEditor:OnLeaveState(state)
    self.btnDNTS:SetPressedState(false)
end

function DNTSEditor:OnEnterState(state)
    self.btnDNTS:SetPressedState(true)
end
