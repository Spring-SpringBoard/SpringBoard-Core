--- MaterialField module.
SB.Include(SB_VIEW_FIELDS_DIR .. "asset_field.lua")

--- MaterialField class.
-- @type MaterialField
MaterialField = AssetField:extends{}

--- MaterialField constructor.
-- @function MaterialField()
-- @see asset_field.AssetField
-- @tparam table opts Table
-- @usage
--function MaterialField:init(field) end

function MaterialField:GetCaption()
    local fname = Path.ExtractFileName(self.value.diffuse or "")
    local index = fname:find("_diffuse")

    if index then
        local texName = fname:sub(1, fname:find("_diffuse") - 1)
        return texName
    else
        return ""
    end
end

function MaterialField:GetPath()
    return self.value.diffuse
end

function MaterialField:MakePickerWindow(tbl)
    return MaterialPickerWindow(tbl)
end
