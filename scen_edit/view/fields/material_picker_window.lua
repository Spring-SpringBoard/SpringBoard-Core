SB.Include(Path.Join(SB_VIEW_FIELDS_DIR, "asset_picker_window.lua"))

MaterialPickerWindow = AssetPickerWindow:extends{}

function MaterialPickerWindow:MakeAssetView(opts)
    return MaterialBrowser({
        name = opts.name,
        ctrl = {
            x = 0,
            right = 0,
            y = 0,
            bottom = opts.bottom,
        },
        rootDir = opts.rootDir,
        dir = opts.dir,
        itemWidth = opts.itemWidth,
        itemHeight = opts.itemHeight,
        OnSelectItem = {
            function(item, selected)
                if not item.texture then
                    return
                end

                CallListeners(opts.OnSelectItem, item.texture)
            end
        },
    })
end
