SB.Include(Path.Join(SB_VIEW_FIELDS_DIR, "asset_picker_window.lua"))

TexturePickerWindow = AssetPickerWindow:extends{}

function TexturePickerWindow:MakeAssetView(rootDir, dir, OnSelectItem)
    return TextureBrowser({
        ctrl = {
            width = "100%",
            height = "100%",
        },
        rootDir = rootDir,
        dir = dir,
        OnSelectItem = {
            function(item, selected)
                if not item.texture then
                    return
                end

                CallListeners(OnSelectItem, item.texture)
            end
        },
    })
end
