-- RmlUi Field Compatibility Layer
-- Provides same API as Chili fields (StringField, NumericField, etc.)
-- so editors don't need to change their code

-- When RmlUi is active, these create RmlUi fields
-- This maintains the exact same API: StringField({name="foo", title="Foo"})

-- Only load if we're using RmlUi mode
if not SB.useRmlUi then
    return
end

SB.Include(Path.Join(SB.DIRS.SRC, 'view/rmlui_fields.lua'))

StringField = RmlUiStringField
NumericField = RmlUiNumericField
BooleanField = RmlUiBooleanField
ChoiceField = RmlUiChoiceField
ColorField = RmlUiColorField
AssetField = RmlUiAssetField
MaterialField = RmlUiMaterialField
ObjectField = RmlUiObjectField
ObjectTypeField = RmlUiObjectTypeField
TeamField = RmlUiTeamField
ArrayField = RmlUiArrayField

-- GroupField wrapper that matches Chili's constructor pattern
-- Auto-generates name like Chili does
local _GROUP_INDEX = 0
function GroupField(fields)
    _GROUP_INDEX = _GROUP_INDEX + 1
    local name = "_groupField" .. tostring(_GROUP_INDEX)
    return RmlUiGroupField({
        name = name,
        fields = fields
    })
end

-- Picker windows
AssetPickerWindow = RmlUiAssetPickerWindow
ColorPickerWindow = RmlUiColorPickerWindow
MaterialPickerWindow = RmlUiMaterialPickerWindow

-- Button classes for RmlUi mode
-- These are created by Editor:_FinalizeRmlUi() when converting Chili buttons to RmlUi

-- Counter for auto-generating button IDs
local _BUTTON_INDEX = 0

-- RmlUi Button (converted from Chili Button:New{} during finalization)
RmlUiButton = LCS.class{}

function RmlUiButton:init(opts)
    _BUTTON_INDEX = _BUTTON_INDEX + 1
    self.id = "btn-" .. tostring(_BUTTON_INDEX)
    self.caption = opts.caption or "Button"
    self.OnClick = opts.OnClick or {}
    self.width = opts.width
    self.height = opts.height
    self.tooltip = opts.tooltip
    self.image = opts.image
    self.element = nil
end

function RmlUiButton:BindToDocument()
    self.element = SB.view.mainDocument:GetElementById(self.id)
    assert(self.element, "Failed to find button element with id: " .. self.id)
end

function RmlUiButton:GenerateRml()
    local title = self.tooltip and string.format(' title="%s"', self.tooltip) or ''
    if self.image then
        -- Documents live in scen_edit/view/rml/, icons in LuaUI/images/scenedit/.
        local imagePath = self.image
        if imagePath:sub(1, 6) == "LuaUI/" then
            imagePath = "../../../" .. imagePath
        end
        return string.format(
            '<button id="%s" class="field-button field-icon-button"%s><img src="%s"/></button>',
            self.id, title, imagePath
        )
    end
    return string.format(
        '<button id="%s" class="field-button"%s>%s</button>',
        self.id, title, self.caption
    )
end

-- A progress bar whose value/caption change after the document exists.
local _PROGRESS_INDEX = 0
RmlUiProgressBar = LCS.class{}

function RmlUiProgressBar:init(opts)
    _PROGRESS_INDEX = _PROGRESS_INDEX + 1
    self.id = "progress-" .. tostring(_PROGRESS_INDEX)
    self.value = opts.value or 0
    self.caption = ""
end

function RmlUiProgressBar:GenerateRml()
    return string.format(
        '<div id="%s" class="field-progress">' ..
        '<div id="%s-fill" class="field-progress-fill" style="width: %d%%;"></div>' ..
        '<div id="%s-caption" class="field-progress-caption"></div></div>',
        self.id, self.id, math.floor(self.value), self.id
    )
end

function RmlUiProgressBar:__Element(suffix)
    local document = (self.owner and self.owner.document) or SB.view.mainDocument
    return document and document:GetElementById(self.id .. suffix)
end

function RmlUiProgressBar:SetValue(value)
    self.value = value
    local fill = self:__Element("-fill")
    if fill then
        fill.style["width"] = tostring(math.floor(value)) .. "%"
    end
end

function RmlUiProgressBar:SetCaption(caption)
    self.caption = tostring(caption or "")
    local element = self:__Element("-caption")
    if element then
        element.inner_rml = self.caption
    end
end

-- A label whose caption changes after the document exists (dialog error lines).
local _LABEL_INDEX = 0
RmlUiLabel = LCS.class{}

function RmlUiLabel:init(opts)
    _LABEL_INDEX = _LABEL_INDEX + 1
    self.id = "label-" .. tostring(_LABEL_INDEX)
    self.caption = opts.caption or ""
end

function RmlUiLabel:GenerateRml()
    return string.format('<div id="%s" class="field-section-label">%s</div>', self.id, self.caption)
end

function RmlUiLabel:__Document()
    -- `owner` is the editor that took this control; a dialog renders into its
    -- own document, not the main one.
    return (self.owner and self.owner.document) or SB.view.mainDocument
end

function RmlUiLabel:SetCaption(caption)
    self.caption = tostring(caption or "")
    local document = self:__Document()
    local element = document and document:GetElementById(self.id)
    if element then
        element.inner_rml = self.caption
    end
end

-- RmlUi TabbedPanelButton (converted from Chili TabbedPanelButton during finalization)
RmlUiTabbedPanelButton = LCS.class{}

function RmlUiTabbedPanelButton:init(opts)
    _BUTTON_INDEX = _BUTTON_INDEX + 1
    self.id = "action-btn-" .. tostring(_BUTTON_INDEX)
    self.x = opts.x
    self.y = opts.y
    self.tooltip = opts.tooltip or ""
    self.OnClick = opts.OnClick or {}
    self.pressed = false
    self.enabled = true
    self.caption = opts.caption or ""
    self.image = opts.image
    self.children = opts.children

    -- Element will be set when bound to document
    self.element = nil
end

function RmlUiTabbedPanelButton:BindToDocument()
    self.element = SB.view.mainDocument:GetElementById(self.id)
    assert(self.element, "Failed to find button element with id: " .. self.id)
end

function RmlUiTabbedPanelButton:SetPressedState(pressed)
    self.pressed = pressed
    self.element:SetClass("pressed", pressed)
end

function RmlUiTabbedPanelButton:SetEnabled(enabled)
    self.enabled = enabled
    self.element:SetClass("disabled", not enabled)
end

function RmlUiTabbedPanelButton:GenerateRml()
    local pressedClass = self.pressed and " pressed" or ""
    local disabledClass = self.enabled and "" or " disabled"
    local html = string.format('<button id="%s" class="action-button%s%s" title="%s">',
        self.id, pressedClass, disabledClass, self.tooltip)

    if self.image then
        -- Make image path relative to RML document (scen_edit/view/rml/)
        -- Icons are at LuaUI/images/scenedit/, so need to go up 3 levels
        local imagePath = self.image
        if imagePath:sub(1, 6) == "LuaUI/" then
            imagePath = "../../../" .. imagePath
        end
        html = html .. string.format('<img src="%s" class="action-button-icon"/>', imagePath)
    end

    if self.caption and self.caption ~= "" then
        html = html .. string.format('<span class="action-button-label">%s</span>', self.caption)
    end

    html = html .. '</button>'
    return html
end

-- RmlUi Label - for filter UI labels
RmlUiLabel = LCS.class{}

function RmlUiLabel:init(opts)
    _BUTTON_INDEX = _BUTTON_INDEX + 1
    self.id = "filter-label-" .. tostring(_BUTTON_INDEX)
    self.caption = opts.caption or ""
    self.x = opts.x
    self.y = opts.y
    self.element = nil
end

function RmlUiLabel:BindToDocument()
    self.element = SB.view.mainDocument:GetElementById(self.id)
    assert(self.element, "Failed to find label element with id: " .. self.id)
end

function RmlUiLabel:GenerateRml()
    return string.format('<span id="%s" class="filter-label">%s</span>', self.id, self.caption)
end

-- RmlUi ComboBox - for filter dropdowns
RmlUiComboBox = LCS.class{}

function RmlUiComboBox:init(opts)
    _BUTTON_INDEX = _BUTTON_INDEX + 1
    self.id = "filter-combo-" .. tostring(_BUTTON_INDEX)
    self.items = opts.items or {}
    self.OnSelect = opts.OnSelect or {}
    self.selected = 1
    self.width = opts.width
    self.x = opts.x
    self.y = opts.y
    self.label = opts.label
    self.element = nil
end

function RmlUiComboBox:BindToDocument()
    self.element = SB.view.mainDocument:GetElementById(self.id)
    assert(self.element, "Failed to find combobox element with id: " .. self.id)
end

function RmlUiComboBox:GenerateRml()
    local html = '<div class="select-wrapper">'
    html = html .. string.format('<select id="%s" class="filter-combo">', self.id)
    for i, item in ipairs(self.items) do
        local selected = (i == self.selected) and ' selected=""' or ''
        html = html .. string.format('<option value="%d"%s>%s</option>', i, selected, item)
    end
    html = html .. '</select>'
    html = html .. '<div class="select-arrow">v</div>'
    html = html .. '</div>'
    return html
end

function RmlUiComboBox:Select(itemIdx)
    self.selected = itemIdx
    self.element.value = tostring(itemIdx)
end

-- RmlUi EditBox - for search text input
RmlUiEditBox = LCS.class{}

function RmlUiEditBox:init(opts)
    _BUTTON_INDEX = _BUTTON_INDEX + 1
    self.id = "filter-edit-" .. tostring(_BUTTON_INDEX)
    self.text = opts.text or ""
    self.OnTextInput = opts.OnTextInput or {}
    self.OnKeyPress = opts.OnKeyPress or {}
    self.width = opts.width
    self.x = opts.x
    self.y = opts.y
    self.element = nil
end

function RmlUiEditBox:BindToDocument()
    self.element = SB.view.mainDocument:GetElementById(self.id)
    assert(self.element, "Failed to find editbox element with id: " .. self.id)
end

function RmlUiEditBox:GenerateRml()
    return string.format('<input type="text" id="%s" class="filter-edit" value="%s" placeholder="Search..."/>',
        self.id, self.text)
end

function RmlUiEditBox:SetText(text)
    self.text = text
    self.element.value = text
end

-- RmlUi PathNavigation - for AssetView directory navigation
RmlUiPathNav = LCS.class{}

function RmlUiPathNav:init(opts)
    _BUTTON_INDEX = _BUTTON_INDEX + 1
    self.id = "path-nav-" .. tostring(_BUTTON_INDEX)
    self.currentPath = opts.currentPath or ""
    self.rootDir = opts.rootDir
    self.imageFolderUp = opts.imageFolderUp
    self.OnUpClick = opts.OnUpClick or {}
    self.editor = opts.editor  -- Optional reference to parent editor for finding document
    self.document = opts.document  -- Pickers render into their own dialog document
    self.documentDepth = opts.documentDepth or 3  -- Default to 3 levels (scen_edit/view/rml/)
end

function RmlUiPathNav:SetPath(path)
    self.currentPath = path
    local document = self.document or (self.editor and self.editor.document) or SB.view.mainDocument
    assert(document, "RmlUiPathNav:SetPath - no document available")

    local pathLabel = document:GetElementById(self.id .. "-path")
    if pathLabel then
        pathLabel.inner_rml = path or ""
    end
end

function RmlUiPathNav:GenerateRml()
    local imagePath = self.imageFolderUp or "LuaUI/Configs/chili/skins/default/folder_up.png"
    -- Convert to relative path from RML document
    -- Default: scen_edit/view/rml/ (3 levels), Pickers: scen_edit/view/rml/fields/ (4 levels)
    if not imagePath:match("^%.%.") and not imagePath:match("^http") then
        local depth = self.documentDepth or 3
        local prefix = string.rep("../", depth)
        imagePath = prefix .. imagePath
    end

    local html = '<div id="' .. self.id .. '" class="path-navigation">'
    html = html .. '<button id="' .. self.id .. '-up" class="path-up-button" title="Go up one directory">'
    html = html .. '<img src="' .. imagePath .. '"/>'
    html = html .. '</button>'
    html = html .. '<span id="' .. self.id .. '-path" class="path-label">' .. self.currentPath .. '</span>'

    if self.rootDir then
        html = html .. '<span class="path-root-label">Root: ' .. tostring(self.rootDir) .. '</span>'
    end

    html = html .. '</div>'
    return html
end

Log.Notice("RmlUi field compatibility layer loaded - original API maintained")
