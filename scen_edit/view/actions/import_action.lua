ImportAction = AbstractAction:extends{}

function ImportAction:execute()
    if Spring.GetGameRulesParam("sb_gameMode") ~= "dev" then
        Log.Warning("Cannot import while testing.")
        return
    end

    local fileTypes = {"Diffuse", "Heightmap"}
    sfd = ImportFileDialog(SB_PROJECTS_DIR, fileTypes)
    sfd:setConfirmDialogCallback(
        function(path, fileType)
            if fileType == fileTypes[2] then
                Log.Notice("Importing diffuse: " .. path .. " ...")
                local importCommand = ImportDiffuseCommand(path)
                SB.commandManager:execute(importCommand, true)
                Log.Notice("Import complete.")
            elseif fileType == fileTypes[3] then
                local ebMinHeight = EditBox:New {
                    hint = "Min height: ",
                    text = ""
                }
                local ebMaxHeight = EditBox:New {
                    hint = "Max height: ",
                    text = "",
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
                                    OnClick = { function()
                                        local maxHeight = tonumber(ebMaxHeight.text)
                                        local minHeight = tonumber(ebMinHeight.text)
                                        if maxHeight == nil or minHeight == nil then
                                            return
                                        end
                                        Log.Notice("Importing heightmap: " .. path .. " ...")
                                        local importCommand = ImportHeightmapCommand(path, maxHeight, minHeight)
                                        SB.commandManager:execute(importCommand, true)
                                        Log.Notice("Import complete.")
                                        window:Dispose()
                                    end},
                                },
                                Button:New {
                                    caption = "Cancel",
                                    OnClick = { function()
                                        window:Dispose()
                                    end},
                                },
                            },
                        }
                    },
                }
            else
                Log.Error("Error trying to export. Invalida fileType specified: " .. tostring(fileType))
            end
        end
    )
end
