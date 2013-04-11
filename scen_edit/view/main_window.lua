MainWindow = LCS.class{}

function MainWindow:init()
    local btnTriggers = Button:New {
        caption = '',
        height = SCEN_EDIT.conf.B_HEIGHT + 20,
        width = SCEN_EDIT.conf.B_HEIGHT + 20,
        tooltip = "Trigger settings",
        children = {
            Image:New {                 
                file=SCEN_EDIT_IMG_DIR .. "applications-system.png", 
                height = SCEN_EDIT.conf.B_HEIGHT - 2, 
                width = SCEN_EDIT.conf.B_HEIGHT - 2,
            },
        },
    }
    local btnVariableSettings = Button:New {
        height = SCEN_EDIT.conf.B_HEIGHT + 20,
        width = SCEN_EDIT.conf.B_HEIGHT + 20,
        caption = '',
        tooltip = "Variable settings",
        children = {
            Image:New {                 
                file=SCEN_EDIT_IMG_DIR .. "format-text-bold.png", 
                height = SCEN_EDIT.conf.B_HEIGHT - 2, 
                width = SCEN_EDIT.conf.B_HEIGHT - 2, 
                margin = {0, 0, 0, 0},
            },
        },
    }

    self.toolboxWindow = Window:New {
        x = 1000,
        y = 100,
        width = 800,
        height = 100,
        parent = screen0,
        caption = "Scenario Toolbox",
        resizable = false,
        children = {
            StackPanel:New {
                name='stack_main',
                orientation = 'horizontal',
                width = '100%',
                height = '100%',
                padding = {0,0,0,0},
                itemPadding = {0,10,10,10},
                itemMargin = {0,0,0,0},
                resizeItems = false,

                children = {
                    Button:New {
                        height = SCEN_EDIT.conf.B_HEIGHT + 20,
                        width = SCEN_EDIT.conf.B_HEIGHT + 220,
                        caption = 'EXPORT-IMG(hello carp)',
                        OnClick = {
                            function()
                                SCEN_EDIT.delayGL(function()
                                    local command = SaveImagesCommand("./")
                                    SCEN_EDIT.commandManager:execute(command, true)
                                end
                                )
                            end
                        },
                    },
                    Button:New {
                        height = SCEN_EDIT.conf.B_HEIGHT + 20,
                        width = SCEN_EDIT.conf.B_HEIGHT + 20,
                        caption = '',
                        OnClick = {
                            function()
                                SCEN_EDIT.stateManager:SetState(AddRectState())
                            end
                        },
                        tooltip = "Add a rectangle area", 
                        children = {
                            Image:New {                                 
                                file=SCEN_EDIT_IMG_DIR .. "view-fullscreen.png", 
                                height = SCEN_EDIT.conf.B_HEIGHT - 2, 
                                width = SCEN_EDIT.conf.B_HEIGHT - 2, 
                                margin = {0, 0, 0, 0},
                            },
                        },
                    },
                    Button:New {
                        height = SCEN_EDIT.conf.B_HEIGHT + 20,
                        width = SCEN_EDIT.conf.B_HEIGHT + 20,
                        caption = '',
                        tooltip = "Save scenario", 
                        OnClick = {
                            function() 
                                local dir = FilePanel.lastDir or SCEN_EDIT_EXAMPLE_DIR_RAW_FS
                                sfd = SaveFileDialog(dir)
                                sfd:setConfirmDialogCallback(function(path)
                                    local saveCommand = SaveCommand(path)
                                    success, errMsg = pcall(function()
                                        SCEN_EDIT.commandManager:execute(saveCommand, true)
                                    end)
                                    if not success then
                                        Spring.Echo(errMsg)
                                    end
                                end)
                            end
                        },
                        children = {
                            Image:New { 
                                file=SCEN_EDIT_IMG_DIR .. "document-save.png", 
                                height = SCEN_EDIT.conf.B_HEIGHT - 2, 
                                width = SCEN_EDIT.conf.B_HEIGHT - 2, 
                                margin = {0, 0, 0, 0},
                            },
                        },
                    },
                    Button:New {
                        height = SCEN_EDIT.conf.B_HEIGHT + 20,
                        width = SCEN_EDIT.conf.B_HEIGHT + 20,
                        caption = '',
                        tooltip = "Load scenario", 
                        OnClick = {
                            function()
                                local dir = FilePanel.lastDir or SCEN_EDIT_EXAMPLE_DIR_RAW_FS
                                ofd = OpenFileDialog(dir)
                                ofd:setConfirmDialogCallback(
                                function(path)
                                    VFS.MapArchive(path)
                                    local data = VFS.LoadFile("model.lua", VFS.ZIP)
                                    cmd = LoadCommand(data)
                                    SCEN_EDIT.commandManager:execute(cmd)

                                    local data = VFS.LoadFile("heightmap.data", VFS.ZIP)
                                    loadMap = LoadMap(data)
                                    SCEN_EDIT.commandManager:execute(loadMap)
                                end)
                            end
                        },
                        children = {
                            Image:New { 
                                file = SCEN_EDIT_IMG_DIR .. "document-open.png", 
                                height = SCEN_EDIT.conf.B_HEIGHT - 2, 
                                width = SCEN_EDIT.conf.B_HEIGHT - 2, 
                                margin = {0, 0, 0, 0},
                            },
                        },
                    },
                    Chili.LayoutPanel:New {
                        height = btnTriggers.height,
                        width = btnTriggers.width,
                        children = {btnTriggers},
                        padding = {0, 0, 0, 0},
                        margin = {0, 0, 0, 0},
                        itemMargin = {0, 0, 0, 0},
                        itemPadding = {0, 0, 0, 0},
                    },
                    Chili.LayoutPanel:New {
                        height = btnVariableSettings.height,
                        width = btnVariableSettings.width,
                        children = {btnVariableSettings},
                        padding = {0, 0, 0, 0},
                        margin = {0, 0, 0, 0},
                        itemMargin = {0, 0, 0, 0},
                        itemPadding = {0, 0, 0, 0},
                    },
                    Button:New {
                        height = SCEN_EDIT.conf.B_HEIGHT + 20,
                        width = SCEN_EDIT.conf.B_HEIGHT + 20,
                        caption = '',
                        tooltip = "Unit type panel",
                        OnClick = {
                            function()
                                self.unitDefsView = UnitDefsView()
                            end
                        },
                        children = {
                            Image:New {                                
                                file = SCEN_EDIT_IMG_DIR .. "face-monkey.png",
                                height = SCEN_EDIT.conf.B_HEIGHT - 2,
                                width = SCEN_EDIT.conf.B_HEIGHT - 2,
                                margin = {0, 0, 0, 0},
                            },
                        },
                    },
                    Button:New {
                        height = SCEN_EDIT.conf.B_HEIGHT + 20,
                        width = SCEN_EDIT.conf.B_HEIGHT + 20,
                        caption = '',
                        tooltip = "Feature type panel",
                        OnClick = {
                            function()
                                self.featureDefsView = FeatureDefsView()
                            end
                        },
                        children = {
                            Image:New {                                
                                file = SCEN_EDIT_IMG_DIR .. "face-monkey.png",
                                height = SCEN_EDIT.conf.B_HEIGHT - 2,
                                width = SCEN_EDIT.conf.B_HEIGHT - 2,
                                margin = {0, 0, 0, 0},
                            },
                        },
                    },--[[
                    Button:New {
                        height = SCEN_EDIT.conf.B_HEIGHT + 20,
                        width = SCEN_EDIT.conf.B_HEIGHT + 20,
                        caption = '',
                        OnClick = {
                            function()
                                Spring.StopSoundStream()
--                                Spring.PlaySoundStream("sounds/environment.ogg")
--                                Spring.PlaySoundFile("sounds/environment.ogg")
--                                Spring.Restart("tb.txt2", "")
--                                local cmd = StartCommand()
--                                SCEN_EDIT.commandManager:execute(cmd)
                            end
                        },
                        children = {
                            Image:New {
                                tooltip = "Start mission",
                                file = SCEN_EDIT_IMG_DIR .. "media-playback-start.png",
                                height = SCEN_EDIT.conf.B_HEIGHT - 2,
                                width = SCEN_EDIT.conf.B_HEIGHT - 2,
                                margin = {0, 0, 0, 0},
                            },
                        },
                    },--]]
                    Button:New {
                        height = SCEN_EDIT.conf.B_HEIGHT + 20,
                        width = SCEN_EDIT.conf.B_HEIGHT + 20,
                        caption = "T-Edit",
                        tooltip = "Terrain toolbox",
                        OnClick = {
                            function()
                                --[[
                                code used to test utf-8; ye it shouldn't be here, but /lazy
                                Spring.Echo("Spring is awesome")
                                Spring.Echo("Proleće je super")
                                Spring.Echo("Пролеће је супер")
                                Spring.Echo("春天很好")
                                Spring.Echo("春はすごい")--]]
                                self.terrainEditorView = TerrainEditorView()
                            end
                        }
                    },
                 }
            }
        }
    }
    btnTriggers.OnClick = {
        function () 
            btnTriggers._toggle = TriggersWindow:New {
                parent = screen0,
                model = SCEN_EDIT.model, 
            }
            btnTriggers.parent.disableChildrenHitTest = true
            table.insert(btnTriggers._toggle.OnDispose, 
                function()
                    if btnTriggers and btnTriggers.parent then
                        btnTriggers.parent.disableChildrenHitTest = false
                    end
                end
            )
        end
    }

    btnVariableSettings.OnClick = {
        function()
            btnVariableSettings._toggle = VariableSettingsWindow:New {
                parent = screen0,
                model = SCEN_EDIT.model, 
            }
            btnVariableSettings.parent.disableChildrenHitTest = true
            table.insert(btnVariableSettings._toggle.OnDispose, 
                function()
                    if btnVariableSettings and btnVariableSettings.parent then
                        btnVariableSettings.parent.disableChildrenHitTest = false
                    end
                end
            )
        end
    }
end
