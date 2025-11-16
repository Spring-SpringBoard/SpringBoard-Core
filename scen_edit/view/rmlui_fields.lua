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
    self.value = opts.value
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
            input.value = value
        end
    end
end

-- Alias for compatibility with Chili field API
function RmlUiField:Set(value)
    self:SetValue(value)
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
    return string.format(
        '<div class="field-row"><label class="field-label">%s:</label><input type="text" id="field-%s" class="field-input" value="%s"/></div>',
        self.title, self.name, self.value or ""
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

    return string.format(
        '<div class="field-row"><label class="field-label">%s:</label><input type="number" %s/></div>',
        self.title, attrs
    )
end

-- Boolean Field
RmlUiBooleanField = RmlUiField:extends{}

function RmlUiBooleanField:init(opts)
    self:super("init", opts)
end

function RmlUiBooleanField:GenerateRml()
    local checked = self.value and 'checked="checked"' or ''
    return string.format(
        '<div class="field-row"><label class="field-label">%s:</label><input type="checkbox" id="field-%s" %s/></div>',
        self.title, self.name, checked
    )
end

-- Choice Field (Dropdown)
RmlUiChoiceField = RmlUiField:extends{}

function RmlUiChoiceField:init(opts)
    self:super("init", opts)
    self.items = opts.items or {}
end

function RmlUiChoiceField:GenerateRml()
    local options = ""
    for _, item in ipairs(self.items) do
        local selected = (item == self.value) and ' selected="selected"' or ''
        options = options .. string.format('<option value="%s"%s>%s</option>', item, selected, item)
    end

    return string.format(
        '<div class="field-row"><label class="field-label">%s:</label><select id="field-%s" class="field-input">%s</select></div>',
        self.title, self.name, options
    )
end

-- Color Field
RmlUiColorField = RmlUiField:extends{}

function RmlUiColorField:init(opts)
    self:super("init", opts)
end

function RmlUiColorField:GenerateRml()
    return string.format(
        '<div class="field-row"><label class="field-label">%s:</label><input type="color" id="field-%s" class="field-input" value="%s"/><button id="btn-pick-%s" class="field-button">Pick</button></div>',
        self.title, self.name, self.value or "#FFFFFF", self.name
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
end

function RmlUiAssetField:GenerateRml()
    return string.format(
        '<div class="field-row"><label class="field-label">%s:</label><input type="text" id="field-%s" class="field-input" value="%s" readonly="readonly"/><button id="btn-browse-%s" class="field-button">Browse</button></div>',
        self.title, self.name, self.value or "", self.name
    )
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
    return string.format(
        '<div class="field-row"><label class="field-label">%s:</label><input type="text" id="field-%s" class="field-input" value="%s" readonly="readonly"/><button id="btn-browse-%s" class="field-button">Browse</button></div>',
        self.title, self.name, self.value or "", self.name
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
    return string.format(
        '<div class="field-row"><label class="field-label">%s:</label><input type="number" id="field-%s" class="field-input" value="%s"/><button id="btn-pick-%s" class="field-button">Pick</button></div>',
        self.title, self.name, self.value or "", self.name
    )
end

-- Object Type Field (unitDef names)
RmlUiObjectTypeField = RmlUiField:extends{}

function RmlUiObjectTypeField:init(opts)
    self:super("init", opts)
end

function RmlUiObjectTypeField:GenerateRml()
    return string.format(
        '<div class="field-row"><label class="field-label">%s:</label><input type="text" id="field-%s" class="field-input" value="%s"/><button id="btn-browse-%s" class="field-button">Browse</button></div>',
        self.title, self.name, self.value or "", self.name
    )
end

-- Team Field
RmlUiTeamField = RmlUiField:extends{}

function RmlUiTeamField:init(opts)
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
    local html = '<div class="field-group">'
    if self.title then
        html = html .. '<label class="field-label">' .. self.title .. ':</label>'
    end

    for _, field in ipairs(self.fields) do
        html = html .. field:GenerateRml()
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
