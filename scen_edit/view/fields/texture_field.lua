SB.Include(SB_VIEW_FIELDS_DIR .. "file_field.lua")

TextureField = AssetField:extends{}

--function TextureField:init(field) end

function TextureField:GetCaption()
    local fname = Path.ExtractFileName(self.value.diffuse or "")
    local index = fname:find("_diffuse")

    if index then
        local texName = fname:sub(1, fname:find("_diffuse") - 1)
        return texName
    else
        return ""
    end
end

function TextureField:GetPath()
    return self.value.diffuse
end

function TextureField:MakePickerWindow(tbl)
    return TexturePickerWindow(tbl)
end
