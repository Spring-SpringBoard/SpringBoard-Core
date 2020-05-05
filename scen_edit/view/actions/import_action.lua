SB.Include(Path.Join(SB.DIRS.SRC, 'view/actions/action.lua'))

ImportAction = Action:extends{}

ImportAction:Register({
    name = "sb_import",
    tooltip = "Import",
    image = SB.DIRS.IMG .. 'open-folder.png',
    toolbar_order = 3,
    hotkey = {
        key = KEYSYMS.I,
        ctrl = true
    }
})

local IMPORT_DIFFUSE = "Diffuse"
local IMPORT_HEIGHTMAP = "Heightmap"
local fileTypes = {IMPORT_DIFFUSE, IMPORT_HEIGHTMAP}

function ImportAction:canExecute()
    if Spring.GetGameRulesParam("sb_gameMode") ~= "dev" then
        Log.Warning("Cannot import while testing.")
        return false
    end
    return true
end

function ImportAction:execute()
    local sfd = ImportFileDialog(SB.DIRS.PROJECTS, fileTypes)
    sfd:setConfirmDialogCallback(
        function(path, fileType)
            local ext = Path.GetExt(path)
            local isImage = table.ifind(SB_IMG_EXTS, ext)

            if fileType == IMPORT_DIFFUSE then
                if not isImage then
                    return false, "Please select an image file"
                end

                Log.Notice("Importing diffuse: " .. path .. " ...")
                local importCommand = ImportDiffuseCommand(path)
                SB.commandManager:execute(importCommand, true)
                Log.Notice("Import complete.")
                return true
            elseif fileType == IMPORT_HEIGHTMAP then
                if not isImage then
                    return false, "Please select an image file"
                end

                self:ImportHeightmap(path)
                return true
            else
                Log.Error("Error trying to export. Invalid fileType specified: " .. tostring(fileType))
                return false, "Internal error. Invalid fileType specified: " .. tostring(fileType)
            end
        end
    )
end

function ImportAction:ImportHeightmap(path)
    local minGroundExtreme, maxGroundExtreme = Spring.GetGroundExtremes()
    local ebMinHeight = EditBox:New {
        hint = "Min height: ",
        text = tostring(minGroundExtreme),
    }
    local ebMaxHeight = EditBox:New {
        hint = "Max height: ",
        text = tostring(maxGroundExtreme),
    }
    local window
    window = Window:New {
        width = 200,
        height = 200,
        x = 550,
        y = 350,
        parent = screen0,
        children = {
            StackPanel:New {
                x = 0, y = 0,
                right = 0, bottom = 0,
                children = {
                    ebMinHeight,
                    ebMaxHeight,
                    Button:New {
                        caption = "OK",
                        OnClick = {
                            function()
                                local minHeight = tonumber(ebMinHeight.text)
                                local maxHeight = tonumber(ebMaxHeight.text)
                                if minHeight == nil or maxHeight == nil then
                                    return
                                end
                                Log.Notice("Importing heightmap: " .. path .. " ...")
                                local importCommand = ImportHeightmapCommand(path, minHeight, maxHeight)
                                SB.commandManager:execute(importCommand, true)
                                window:Dispose()
                            end
                        },
                    },
                    Button:New {
                        caption = "Cancel",
                        OnClick = {
                            function()
                                window:Dispose()
                            end
                        },
                    },
                },
            }
        },
    }
end
