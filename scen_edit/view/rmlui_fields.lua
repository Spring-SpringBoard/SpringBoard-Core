-- RmlUi Field Type Stubs
-- These are form field components used within editors
-- Implementation-agnostic: No need to touch RML/HTML to add fields!
-- Just use: AddField(StringField({name="foo", title="Foo"}))

-- Only load if RmlUi is available
if not RmlUi then
    return
end

-- Base Field Class
RmlUiField = LCS.class{}

function RmlUiField:init(opts)
    self.name = opts.name
    self.title = opts.title or opts.name
    self.value = opts.value or ""  -- Default to empty string if no value provided
    self.width = opts.width or 200
    self.element = nil  -- Will be set when rendered
end

function RmlUiField:GetValue()
    if self.element then
        -- Try to get value from actual DOM element
        local input = self.element:GetElementById("field-" .. self.name)
        if input and input.value then
            return input.value
        end
    end
    return self.value
end

function RmlUiField:SetValue(value)
    self.value = value
    if self.element then
        local input = self.element:GetElementById("field-" .. self.name)
        if input then
            input:SetAttribute("value", tostring(value or ""))
        end
    end
end

-- Set field value and notify editor (matches Chili Field:Set behavior)
function RmlUiField:Set(value, source)
    if self.__inUpdate then
        return
    end
    self.__inUpdate = true

    -- Validate value if validator exists
    local valid, validatedValue = true, value
    if self.Validate then
        valid, validatedValue = self:Validate(value)
    end

    -- Only update if value changed and is valid
    if valid and validatedValue ~= self.value then
        self.value = validatedValue

        -- Update DOM
        if SB.view and SB.view.mainDocument then
            local input = SB.view.mainDocument:GetElementById("field-" .. self.name)
            if input then
                input:SetAttribute("value", tostring(validatedValue or ""))
            end
        end

        -- Notify editor
        if self.ev then
            self.ev:Update(self.name, source)
        end
    end

    self.__inUpdate = false
end

function RmlUiField:Focus()
    -- Focus the input element (for dialogs)
    if SB.view and SB.view.mainDocument then
        local input = SB.view.mainDocument:GetElementById("field-" .. self.name)
        if input and input.Focus then
            input:Focus()
        end
    end
end

function RmlUiField:UpdateDisplay()
    -- Override in subclass
end

function RmlUiField:GenerateRml()
    -- Override in subclass to return RML string
    -- This is the ONLY place RML is generated - programmatically!
    return '<div class="field-row"><label class="field-label">' .. self.title .. '</label></div>'
end

-- String Field
RmlUiStringField = RmlUiField:extends{}

function RmlUiStringField:init(opts)
    self:super("init", opts)
end

function RmlUiStringField:GenerateRml()
    -- Remove trailing colon from title if present
    local title = self.title:gsub(":$", "")
    return string.format(
        '<div class="field-row"><label class="field-label">%s:</label><input type="text" id="field-%s" class="field-input" value="%s"/></div>',
        title, self.name, self.value or ""
    )
end

-- Numeric Field
RmlUiNumericField = RmlUiField:extends{}

function RmlUiNumericField:init(opts)
    self:super("init", opts)
    self.min = opts.min
    self.max = opts.max
    self.step = opts.step
end

function RmlUiNumericField:GenerateRml()
    local attrs = string.format('id="field-%s" class="field-input" value="%s"',
        self.name, self.value or 0)
    if self.min then attrs = attrs .. ' min="' .. self.min .. '"' end
    if self.max then attrs = attrs .. ' max="' .. self.max .. '"' end
    if self.step then attrs = attrs .. ' step="' .. self.step .. '"' end
    -- Remove trailing colon from title if present
    local title = self.title:gsub(":$", "")

    return string.format(
        '<div class="field-row"><label class="field-label">%s:</label><input type="number" %s/></div>',
        title, attrs
    )
end

-- Boolean Field
RmlUiBooleanField = RmlUiField:extends{}

function RmlUiBooleanField:init(opts)
    self:super("init", opts)
end

function RmlUiBooleanField:GetValue()
    if self.element then
        -- Checkboxes use 'checked' property, not 'value'
        local input = self.element:GetElementById("field-" .. self.name)
        if input then
            return input.checked
        end
    end
    return self.value
end

function RmlUiBooleanField:SetValue(value)
    self.value = value
    if self.element then
        local input = self.element:GetElementById("field-" .. self.name)
        if input then
            input.checked = value
        end
    end
end

function RmlUiBooleanField:GenerateRml()
    local checked = self.value and 'checked="checked"' or ''
    -- Remove trailing colon from title if present
    local title = self.title:gsub(":$", "")
    return string.format(
        '<div class="field-row"><label class="field-label">%s:</label><input type="checkbox" id="field-%s" class="field-checkbox" %s/></div>',
        title, self.name, checked
    )
end

-- Choice Field (Dropdown)
RmlUiChoiceField = RmlUiField:extends{}

function RmlUiChoiceField:init(opts)
    self:super("init", opts)
    self.items = opts.items or {}
    self.captions = opts.captions or self.items  -- Use items as captions if not provided
end

function RmlUiChoiceField:GenerateRml()
    local options = ""
    for i, item in ipairs(self.items) do
        local caption = self.captions[i] or tostring(item)
        local selected = (tostring(item) == tostring(self.value)) and ' selected="selected"' or ''
        options = options .. string.format('<option value="%s"%s>%s</option>', tostring(item), selected, caption)
    end
    -- Remove trailing colon from title if present
    local title = self.title:gsub(":$", "")

    return string.format(
        '<div class="field-row"><label class="field-label">%s:</label><select id="field-%s" class="field-input">%s</select></div>',
        title, self.name, options
    )
end

function RmlUiChoiceField:GetCaption(id)
    id = id or self.value
    -- Find index of id in items
    for i, item in ipairs(self.items) do
        if tostring(item) == tostring(id) then
            return self.captions[i]
        end
    end
    return nil
end

-- Color Field
RmlUiColorField = RmlUiField:extends{}

function RmlUiColorField:init(opts)
    self:super("init", opts)
end

function RmlUiColorField:GenerateRml()
    -- Convert color to hex string
    local colorHex = "#FFFFFF"
    if self.value then
        if type(self.value) == "table" then
            -- Chili format: {r, g, b, a} where values are 0-1
            local r = math.floor((self.value[1] or self.value.r or 1) * 255)
            local g = math.floor((self.value[2] or self.value.g or 1) * 255)
            local b = math.floor((self.value[3] or self.value.b or 1) * 255)
            colorHex = string.format("#%02X%02X%02X", r, g, b)
        else
            colorHex = tostring(self.value)
        end
    end

    return string.format(
        '<div class="field-row"><label class="field-label">%s:</label><input type="color" id="field-%s" class="field-input" value="%s"/><button id="btn-pick-%s" class="field-button">Pick</button></div>',
        self.title, self.name, colorHex, self.name
    )
end

function RmlUiColorField:ShowColorPicker()
    local picker = RmlUiColorPickerWindow({
        color = self.value,
        onConfirm = function(color)
            self:SetValue(color)
            return true
        end
    })
    picker:Show()
end

-- Asset Field
RmlUiAssetField = RmlUiField:extends{}

function RmlUiAssetField:init(opts)
    self:super("init", opts)
    self.assetType = opts.assetType
    self.expand = opts.expand
    self.rootDir = opts.rootDir
    self.itemWidth = opts.itemWidth or 64
    self.itemHeight = opts.itemHeight or 64

    -- If opts.Update is provided, it overrides the Update method (like Chili)
    if opts.Update then
        self.Update = opts.Update
    end

    -- Create AssetView for expand mode (mimics Chili AssetPickerWindow behavior)
    if self.expand then
        self.assetView = AssetView({
            dir = "core/",
            rootDir = self.rootDir,
            itemWidth = self.itemWidth,
            itemHeight = self.itemHeight,
            multiSelect = false,
            imageFolder = Path.Join(SB.DIRS.IMG, 'open-folder.png'),
            imageFolderUp = Path.Join(SB.DIRS.IMG, 'up-card.png'),
            OnSelectItem = {
                function(item, selected)
                    self:Set(item.path)
                end
            },
        })

        -- Explicitly trigger directory scan to populate items
        -- AssetView:init already calls SetDir, but we ensure it happens
        self.assetView:SetDir("core/")

    end
end

function RmlUiAssetField:Update(source)
    -- RmlUi version of AssetField:Update
    -- In expand mode with AssetView, we might need to update the selected item
    if self.expand and self.assetView and source ~= self.assetView then
        -- Update AssetView selection if needed
        if self.value then
            self.assetView:SelectAsset(self.value)
        end
    end
end

function RmlUiAssetField:GenerateRml()
    if self.expand then
        -- Expanded mode: embed AssetView grid inline
        if self.assetView then
            -- Generate path navigation
            local html = ''
            if self.assetView.pathNav then
                html = self.assetView.pathNav:GenerateRml()
            end

            -- Generate grid container
            html = html .. string.format('<div id="%s" class="grid-container" style="height: 200dp;"></div>', self.assetView.gridId)

            return html
        else
            return '<p style="color: #ff0000;">Error: AssetView not initialized</p>'
        end
    else
        -- Compact mode: show text input + browse button
        local valueStr = ""
        if self.value then
            valueStr = type(self.value) == "table" and (self.value.name or "") or tostring(self.value)
        end
        -- Remove trailing colon from title if present
        local title = self.title:gsub(":$", "")

        return string.format(
            '<div class="field-row"><label class="field-label">%s:</label><input type="text" id="field-%s" class="field-input" value="%s" readonly="readonly"/><button id="btn-browse-%s" class="field-button">Browse</button></div>',
            title, self.name, valueStr, self.name
        )
    end
end

function RmlUiAssetField:BindEvents()
    if not self.expand or not SB.view.mainDocument then
        return
    end

    -- Bind path navigation events and update grid
    if self.assetView then

        -- Bind path navigation up button if it exists
        if self.assetView.pathNav then
            local upBtn = SB.view.mainDocument:GetElementById(self.assetView.pathNav.id .. "-up")
            if upBtn then
                upBtn:AddEventListener("click", function()
                    -- Call the OnUpClick handlers
                    for _, listener in ipairs(self.assetView.pathNav.OnUpClick) do
                        listener()
                    end
                end)
            end
        end

        -- Trigger grid population
        SB.delay(function()
            self.assetView:_UpdateRmlUiGrid()
        end)
    end
end

function RmlUiAssetField:ShowAssetPicker()
    local picker = RmlUiAssetPickerWindow({
        assetType = self.assetType,
        onConfirm = function(assetPath)
            self:SetValue(assetPath)
            return true
        end
    })
    picker:Show()
end

-- Material Field
RmlUiMaterialField = RmlUiField:extends{}

function RmlUiMaterialField:init(opts)
    self:super("init", opts)
end

function RmlUiMaterialField:GenerateRml()
    -- Convert value to string (might be table in some cases)
    local valueStr = ""
    if self.value then
        valueStr = type(self.value) == "table" and (self.value.name or "") or tostring(self.value)
    end
    -- Remove trailing colon from title if present
    local title = self.title:gsub(":$", "")

    return string.format(
        '<div class="field-row"><label class="field-label">%s:</label><input type="text" id="field-%s" class="field-input" value="%s" readonly="readonly"/><button id="btn-browse-%s" class="field-button">Browse</button></div>',
        title, self.name, valueStr, self.name
    )
end

function RmlUiMaterialField:ShowMaterialPicker()
    local picker = RmlUiMaterialPickerWindow({
        onConfirm = function(material)
            self:SetValue(material)
            return true
        end
    })
    picker:Show()
end

-- Object Field (for object IDs)
RmlUiObjectField = RmlUiField:extends{}

function RmlUiObjectField:init(opts)
    self:super("init", opts)
end

function RmlUiObjectField:GenerateRml()
    -- Convert value to string (might be table in some cases)
    local valueStr = ""
    if self.value then
        valueStr = type(self.value) == "table" and (self.value.id or "") or tostring(self.value)
    end
    -- Remove trailing colon from title if present
    local title = self.title:gsub(":$", "")

    return string.format(
        '<div class="field-row"><label class="field-label">%s:</label><input type="number" id="field-%s" class="field-input" value="%s"/><button id="btn-pick-%s" class="field-button">Pick</button></div>',
        title, self.name, valueStr, self.name
    )
end

-- Object Type Field (unitDef names)
RmlUiObjectTypeField = RmlUiField:extends{}

function RmlUiObjectTypeField:init(opts)
    self:super("init", opts)
end

function RmlUiObjectTypeField:GenerateRml()
    -- Convert value to string (might be table in some cases)
    local valueStr = ""
    if self.value then
        valueStr = type(self.value) == "table" and (self.value.name or "") or tostring(self.value)
    end
    -- Remove trailing colon from title if present
    local title = self.title:gsub(":$", "")

    return string.format(
        '<div class="field-row"><label class="field-label">%s:</label><input type="text" id="field-%s" class="field-input" value="%s"/><button id="btn-browse-%s" class="field-button">Browse</button></div>',
        title, self.name, valueStr, self.name
    )
end

-- Team Field
RmlUiTeamField = RmlUiField:extends{}

function RmlUiTeamField:init(opts)
    -- Set default value to 0 if not provided (matching ChoiceField behavior)
    if opts.value == nil then
        opts.value = 0
    end
    self:super("init", opts)
end

function RmlUiTeamField:GenerateRml()
    local options = ""
    for i = 0, 15 do
        local selected = (i == self.value) and ' selected="selected"' or ''
        options = options .. string.format('<option value="%d"%s>Team %d</option>', i, selected, i)
    end

    return string.format(
        '<div class="field-row"><label class="field-label">%s:</label><select id="field-%s" class="field-input">%s</select></div>',
        self.title, self.name, options
    )
end

-- Array Field
RmlUiArrayField = RmlUiField:extends{}

function RmlUiArrayField:init(opts)
    self:super("init", opts)
    self.value = opts.value or {}
    self.itemType = opts.itemType or "string"
end

function RmlUiArrayField:GenerateRml()
    local html = '<div class="array-field"><label class="field-label">' .. self.title .. ':</label>'

    for i, item in ipairs(self.value) do
        html = html .. string.format(
            '<div class="array-item"><input type="text" class="array-item-input field-input" value="%s"/><button class="array-item-remove field-button">-</button></div>',
            item
        )
    end

    html = html .. '<button class="array-add-button field-button">+ Add Item</button></div>'
    return html
end

-- Group Field (groups multiple fields together)
RmlUiGroupField = RmlUiField:extends{}

function RmlUiGroupField:init(opts)
    self:super("init", opts)
    self.fields = opts.fields or {}
end

function RmlUiGroupField:GenerateRml()
    -- Group fields display children inline without showing group name
    local html = '<div class="field-group">'

    -- Only show label if explicitly provided (not auto-generated "_groupField" names)
    if self.title and not self.title:match("^_groupField%d+$") then
        local title = self.title:gsub(":$", "")
        html = html .. '<label class="field-label">' .. title .. ':</label>'
    end

    for _, field in ipairs(self.fields) do
        -- Generate inline field HTML (without the field-row wrapper)
        if field.GenerateRml then
            -- For group children, generate compact inline version
            local fieldHtml = field:GenerateRml()
            -- Remove the field-row wrapper for inline display
            fieldHtml = fieldHtml:gsub('<div class="field%-row">', '<div class="field-inline">')
            html = html .. fieldHtml
        end
    end

    html = html .. '</div>'
    return html
end

-- Picker Windows
RmlUiAssetPickerWindow = RmlUiComponent:extends{}
function RmlUiAssetPickerWindow:init(opts)
    self:super("init", Path.Join(SB.DIRS.SRC, 'view/rml/fields/asset_picker.rml'), "Asset Picker")
    self.assetType = opts.assetType
    self.onConfirm = opts.onConfirm
end

RmlUiColorPickerWindow = RmlUiComponent:extends{}
function RmlUiColorPickerWindow:init(opts)
    self:super("init", Path.Join(SB.DIRS.SRC, 'view/rml/fields/color_picker.rml'), "Color Picker")
    self.color = opts.color
    self.onConfirm = opts.onConfirm
end

RmlUiMaterialPickerWindow = RmlUiComponent:extends{}
function RmlUiMaterialPickerWindow:init(opts)
    self:super("init", Path.Join(SB.DIRS.SRC, 'view/rml/fields/material_picker.rml'), "Material Picker")
    self.onConfirm = opts.onConfirm
end
