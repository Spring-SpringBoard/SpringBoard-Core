SB.Include(Path.Join(SB.DIRS.SRC, 'view/editor.lua'))
SB.Include(Path.Join(SB.DIRS.SRC, 'view/map/material_browser.lua'))
SB.Include(Path.Join(SB.DIRS.SRC, 'view/map/saved_brushes.lua'))

TextureEditor = Editor:extends{}
TextureEditor:Register({
    name = "textureEditor",
    tab = "Map",
    caption = "Texture",
    tooltip = "Edit textures",
    image = Path.Join(SB.DIRS.IMG, 'palette.png'),
    order = 1,
})

function TextureEditor:init(model)
    self:super("init")
    self.model = model or TextureEditorModel()
    self.matFieldNames = {}

    local fieldDefs = self.model:GetFieldDefinitions()
    for _, fieldDef in ipairs(fieldDefs) do
        self:AddFieldFromDef(fieldDef)
    end

    local matFields = self.model:GetMaterialTextureFields()
    local matFieldsGroup = {}
    for _, fieldDef in ipairs(matFields) do
        table.insert(matFieldsGroup, BooleanField({
            name = fieldDef.name,
            value = fieldDef.value,
            title = fieldDef.title,
            tooltip = fieldDef.tooltip,
            width = fieldDef.width,
        }))
        table.insert(self.matFieldNames, fieldDef.name)
        if #matFieldsGroup == 3 then
            self:AddField(GroupField(matFieldsGroup))
            matFieldsGroup = {}
        end
    end
    if #matFieldsGroup ~= 0 then
        self:AddField(GroupField(matFieldsGroup))
    end

    self.savedBrushes = SavedBrushes({
        ctrl = {
            x = 0,
            right = 0,
            y = 70,
            bottom = "65%",
        },
        editor = self,
        name = "mapMaterials",
        GetNewBrush = function()
            local tbl = self:Serialize()
            CallListeners(self.fields["brushTexture"].button.OnClick)
            return {
                opts = tbl,
                caption = nil,
                image = "",
                tooltip = nil,
            }
        end,
        GetBrushImage = function(brush)
            local texturePath = brush.opts.brushTexture.diffuse
            local texName = brush.image
            if texName == nil or texName == "" then
                texName = BrushDrawer.GetBrushTexture(
                    self.savedBrushes.itemWidth,
                    self.savedBrushes.itemHeight)
            end
            BrushDrawer.UpdateLuaTexture(texName,
                texturePath,
                self.savedBrushes.itemWidth,
                self.savedBrushes.itemHeight,
                BrushDrawer.GetBrushDrawOpts(brush))
            return texName
        end,
    })

    self.savedDNTSBrushes = SavedBrushes({
        ctrl = {
            x = 0,
            right = 0,
            y = 70,
            bottom = "65%",
        },
        editor = self,
        disableAdd = true,
        disableRemove = true,
        name = "mapDNTS",
        GetNewBrush = function()
            local tbl = self:Serialize()
            CallListeners(self.fields["brushTexture"].button.OnClick)
            return {
                opts = tbl,
                caption = nil,
                image = "",
                tooltip = nil,
            }
        end,
        GetBrushImage = function(brush)
            local texObj = SB.model.textureManager.shadingTextures["splat_normals" ..
                tostring(brush.opts.dntsIndex)]
            if not texObj then
                Log.Warning("Couldn't find texture for DNTS: ", "splat_normals" ..
                tostring(brush.opts.dntsIndex))
                return
            end
            local texturePath = texObj.texture
            local texName = brush.image
            if texName == nil or texName == "" or texName:sub(1, 1) == "$" then
                texName = BrushDrawer.GetBrushTexture(
                    self.savedBrushes.itemWidth,
                    self.savedBrushes.itemHeight)
            end
            BrushDrawer.UpdateLuaTexture(texName,
                texturePath,
                self.savedBrushes.itemWidth,
                self.savedBrushes.itemHeight,
                BrushDrawer.GetBrushDrawOpts(brush))
            return texName
        end,
    })

    local toolModes = self.model:GetToolModes()
    self.toolButtons = {}
    for i, toolMode in ipairs(toolModes) do
        local x = (i - 1) * SB.conf.TOOLBOX_ITEM_WIDTH
        local btn = TabbedPanelButton({
            x = x,
            y = 0,
            tooltip = toolMode.tooltip,
            children = {
                TabbedPanelImage({ file = Path.Join(SB.DIRS.IMG, toolMode.icon) }),
                TabbedPanelLabel({ caption = toolMode.caption }),
            },
            OnClick = {
                function()
                    self:EnterToolMode(toolMode.id)
                end
            },
        })
        self.toolButtons[toolMode.id] = btn
    end

    self:AddDefaultKeybinding({
        self.toolButtons["paint"],
        self.toolButtons["blur"],
        self.toolButtons["dnts"],
        self.toolButtons["void"],
    })

    local children = {
        self.toolButtons["paint"],
        self.toolButtons["blur"],
        self.toolButtons["dnts"],
        self.toolButtons["void"],
        self.savedBrushes:GetControl(),
        self.savedDNTSBrushes:GetControl(),
        ScrollPanel:New {
            x = 0,
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

    SB.delay(function()
        for i = 0, 3 do
            local texturePath = SB.model.textureManager.shadingTextures["splat_normals" ..
                tostring(i)]
            if texturePath then
                self:__AddEngineDNTSTexture(i)
            end
        end
        self.savedDNTSBrushes:DeselectAll()
        if #self.savedDNTSBrushes.brushManager:GetBrushIDs() == 0 then
            self.toolButtons["dnts"]:SetEnabled(false)
            self.toolButtons["dnts"].tooltip = "\255\255\1\1(DISABLED)\b\255\255\255\255No DNTS textures detected for current map.\b"
        end
    end)

    self:Finalize(children)
    self.savedDNTSBrushes:GetControl():Hide()
end

function TextureEditor:AddFieldFromDef(fieldDef)
    if fieldDef.type == "asset" then
        self:AddField(AssetField({
            name = fieldDef.name,
            title = fieldDef.title,
            rootDir = fieldDef.rootDir,
            expand = fieldDef.expand,
            itemWidth = fieldDef.itemWidth,
            itemHeight = fieldDef.itemHeight,
            Validate = fieldDef.validateFunc,
        }))
    elseif fieldDef.type == "material" then
        self:AddField(MaterialField({
            name = fieldDef.name,
            title = fieldDef.title,
            value = fieldDef.value,
            rootDir = fieldDef.rootDir,
            width = fieldDef.width,
        }))
    elseif fieldDef.type == "choice" then
        self:AddField(ChoiceField({
            name = fieldDef.name,
            items = fieldDef.items,
            title = fieldDef.title,
        }))
    elseif fieldDef.type == "boolean" then
        self:AddField(BooleanField({
            name = fieldDef.name,
            title = fieldDef.title,
            value = fieldDef.value,
        }))
    elseif fieldDef.type == "numeric" then
        self:AddField(NumericField({
            name = fieldDef.name,
            value = fieldDef.value,
            minValue = fieldDef.min,
            maxValue = fieldDef.max,
            step = fieldDef.step,
            decimals = fieldDef.decimals,
            title = fieldDef.title,
            tooltip = fieldDef.tooltip,
            width = fieldDef.width,
        }))
    elseif fieldDef.type == "color" then
        self:AddField(ColorField({
            name = fieldDef.name,
            title = fieldDef.title,
            value = fieldDef.value,
            width = fieldDef.width,
            format = fieldDef.format,
        }))
    elseif fieldDef.type == "hidden" then
        self:AddField(Field({
            name = fieldDef.name,
            value = fieldDef.value,
        }))
    elseif fieldDef.type == "separator" then
        self:AddControl(fieldDef.name, {
            Label:New {
                caption = fieldDef.caption,
            },
            Line:New {
                x = 50,
                y = 4,
                width = self.VALUE_POS,
            }
        })
    elseif fieldDef.type == "group" then
        local groupFields = {}
        for _, subFieldDef in ipairs(fieldDef.fields) do
            if subFieldDef.type == "numeric" then
                table.insert(groupFields, NumericField({
                    name = subFieldDef.name,
                    value = subFieldDef.value,
                    minValue = subFieldDef.min,
                    maxValue = subFieldDef.max,
                    step = subFieldDef.step,
                    decimals = subFieldDef.decimals,
                    title = subFieldDef.title,
                    tooltip = subFieldDef.tooltip,
                    width = subFieldDef.width,
                }))
            end
        end
        self:AddField(GroupField(groupFields))
    end
end

function TextureEditor:EnterToolMode(modeId)
    self.model:SetMode(modeId)

    if modeId == "paint" then
        self:_EnterState("paint")
        self.savedBrushes:GetControl():Show()
        self.savedDNTSBrushes:GetControl():Hide()
    elseif modeId == "blur" then
        self:_EnterState("blur")
        self.savedBrushes:GetControl():Hide()
        self.savedDNTSBrushes:GetControl():Hide()
    elseif modeId == "dnts" then
        if #self.savedDNTSBrushes.brushManager:GetBrushIDs() == 0 then
            return
        end
        self:_EnterState("dnts")
        self.savedBrushes:GetControl():Hide()
        self.savedDNTSBrushes:GetControl():Show()
    elseif modeId == "void" then
        self:_EnterState("void")
        self.savedBrushes:GetControl():Hide()
        self.savedDNTSBrushes:GetControl():Hide()
    end

    self:UpdateFieldVisibility()
end

function TextureEditor:UpdateFieldVisibility()
    local visibleFields = self.model:GetVisibleFieldsForMode(self.model:GetCurrentMode())
    local allFields = {"patternTexture", "brushTexture", "mode", "kernelMode", "exclusive",
                      "size", "rotation", "texScale", "texRotation", "texOffsetX", "texOffsetY",
                      "strength", "falloffFactor", "featureFactor", "value", "voidFactor",
                      "splatTexScale", "splatTexMult", "diffuseColor",
                      "offset-sep", "tex-sep", "blending-sep", "splat-sep"}

    for _, matFieldName in ipairs(self.matFieldNames) do
        table.insert(allFields, matFieldName)
    end

    local invisibleFields = {}
    for _, field in ipairs(allFields) do
        local isVisible = false
        for _, vf in ipairs(visibleFields) do
            if vf == field then
                isVisible = true
                break
            end
        end
        if not isVisible then
            table.insert(invisibleFields, field)
        end
    end
    self:SetInvisibleFields(unpack(invisibleFields))
end

function TextureEditor:__AddEngineDNTSTexture(dntsIndex)
    local tbl = self:Serialize()
    tbl.dntsIndex = dntsIndex

    if gl.GetMapRendering then
        local splatTexScales = {gl.GetMapRendering("splatTexScales")}
        local splatTexMults = {gl.GetMapRendering("splatTexMults")}
        tbl.splatTexScale = splatTexScales[dntsIndex]
        tbl.splatTexMult = splatTexMults[dntsIndex]
    end

    self.savedDNTSBrushes:AddBrush({
        opts = tbl,
        caption = "DNTS:" .. tostring(dntsIndex),
        tooltip = nil,
    })
end

function TextureEditor:OnStartChange(name)
    self.model:OnStartChange(name)
end

function TextureEditor:OnEndChange(name)
    self.model:OnEndChange(name)
end

function TextureEditor:OnFieldChange(name, value)
    self.model:HandleFieldChange(name, value, self.savedBrushes, self.savedDNTSBrushes, self.fields)
end

function TextureEditor:_EnterState(paintMode)
    local state = TerrainChangeTextureState(self)
    state.paintMode = paintMode
    SB.stateManager:SetState(state)
end

function TextureEditor:IsValidState(state)
    return self.model:IsValidState(state)
end

function TextureEditor:OnLeaveState(state)
    for _, btn in pairs(self.toolButtons) do
        btn:SetPressedState(false)
    end
end

function TextureEditor:OnEnterState(state)
    local modeId = state.paintMode
    self.model:SetMode(modeId)
    self.toolButtons[modeId]:SetPressedState(true)
end
