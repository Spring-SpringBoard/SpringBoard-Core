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
        html = html .. string.format('<img src="%s" class="action-button-icon"/>', self.image)
    end

    if self.caption and self.caption ~= "" then
        html = html .. string.format('<span class="action-button-label">%s</span>', self.caption)
    end

    html = html .. '</button>'
    return html
end

Log.Notice("RmlUi field compatibility layer loaded - original API maintained")
