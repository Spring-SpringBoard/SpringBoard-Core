-- RmlUi Field Compatibility Layer
-- Provides same API as Chili fields (StringField, NumericField, etc.)
-- so editors don't need to change their code

-- When RmlUi is active, these create RmlUi fields
-- This maintains the exact same API: StringField({name="foo", title="Foo"})

-- Only load if RmlUi is available
if not RmlUi then
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
end

function RmlUiButton:GenerateRml()
    return string.format(
        '<button id="%s" class="field-button">%s</button>',
        self.id, self.caption
    )
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
end

function RmlUiTabbedPanelButton:SetPressedState(pressed)
    self.pressed = pressed
    -- Update DOM if we have the button element
    if SB.view and SB.view.mainDocument then
        local btnElement = SB.view.mainDocument:GetElementById(self.id)
        if btnElement then
            btnElement:SetClass("pressed", pressed)
        end
    end
end

function RmlUiTabbedPanelButton:SetEnabled(enabled)
    self.enabled = enabled
    -- Update DOM if we have the button element
    if SB.view and SB.view.mainDocument then
        local btnElement = SB.view.mainDocument:GetElementById(self.id)
        if btnElement then
            if enabled then
                btnElement:RemoveAttribute("disabled")
            else
                btnElement:SetAttribute("disabled", "")
            end
        end
    end
end

function RmlUiTabbedPanelButton:GenerateRml()
    local pressedClass = self.pressed and " pressed" or ""
    local disabledAttr = self.enabled and "" or ' disabled=""'
    local html = string.format('<button id="%s" class="action-button%s" title="%s"%s>',
        self.id, pressedClass, self.tooltip, disabledAttr)

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
end

function RmlUiComboBox:GenerateRml()
    local html = string.format('<select id="%s" class="filter-combo">', self.id)
    for i, item in ipairs(self.items) do
        local selected = (i == self.selected) and ' selected=""' or ''
        html = html .. string.format('<option value="%d"%s>%s</option>', i, selected, item)
    end
    html = html .. '</select>'
    return html
end

function RmlUiComboBox:Select(itemIdx)
    self.selected = itemIdx
    -- Update DOM if element exists
    if SB.view and SB.view.mainDocument then
        local element = SB.view.mainDocument:GetElementById(self.id)
        if element then
            element.value = tostring(itemIdx)
        end
    end
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
end

function RmlUiEditBox:GenerateRml()
    return string.format('<input type="text" id="%s" class="filter-edit" value="%s" placeholder="Search..."/>',
        self.id, self.text)
end

function RmlUiEditBox:SetText(text)
    self.text = text
    -- Update DOM if element exists
    if SB.view and SB.view.mainDocument then
        local element = SB.view.mainDocument:GetElementById(self.id)
        if element then
            element.value = text
        end
    end
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
end

function RmlUiPathNav:SetPath(path)
    self.currentPath = path
    -- Update DOM if element exists
    if SB.view and SB.view.mainDocument then
        local pathLabel = SB.view.mainDocument:GetElementById(self.id .. "-path")
        if pathLabel then
            pathLabel.inner_rml = path or ""
        end
    end
end

function RmlUiPathNav:GenerateRml()
    local imagePath = self.imageFolderUp or "LuaUI/images/folder_up.png"
    if imagePath:sub(1, 6) == "LuaUI/" then
        imagePath = "../../../" .. imagePath
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
