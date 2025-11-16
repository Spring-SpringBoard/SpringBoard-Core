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
GroupField = RmlUiGroupField

-- Picker windows
AssetPickerWindow = RmlUiAssetPickerWindow
ColorPickerWindow = RmlUiColorPickerWindow
MaterialPickerWindow = RmlUiMaterialPickerWindow

Log.Notice("RmlUi field compatibility layer loaded - original API maintained")
