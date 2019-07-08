SB.Include(Path.Join(SB_VIEW_ACTIONS_DIR, "action.lua"))

ExportAction = Action:extends{}

ExportAction:Register({
    name = "sb_export",
    tooltip = "Export",
    image = SB_IMG_DIR .. "save.png",
    toolbar_order = 6,
    hotkey = {
        key = KEYSYMS.E,
        ctrl = true
    }
})

ExportAction.EXPORT_SPRING_ARCHIVE = "Spring archive"
ExportAction.EXPORT_MAP_TEXTURES = "Map textures"
ExportAction.EXPORT_MAP_INFO = "Map info"
ExportAction.EXPORT_S11N = "s11n object format"
local fileTypes = {
    ExportAction.EXPORT_SPRING_ARCHIVE,
    ExportAction.EXPORT_MAP_TEXTURES,
    ExportAction.EXPORT_MAP_INFO,
    ExportAction.EXPORT_S11N
}

function ExportAction:canExecute()
    if Spring.GetGameRulesParam("sb_gameMode") ~= "dev" then
        Log.Warning("Cannot export while testing.")
        return false
    end
    if SB.project.path == nil then
        -- FIXME: this should probably be relaxed for most types of export
        Log.Warning("The project must be saved before exporting")
        return false
    end
    return true
end

function ExportAction:execute()
    ExportFileDialog(SB_EXPORTS_DIR, fileTypes):setConfirmDialogCallback(
        function(path, fileType, heightmapExtremes)
            local baseName = Path.ExtractFileName(path)
            local isFile = VFS.FileExists(path, VFS.RAW_ONLY)
            local isDir = SB.DirExists(path, VFS.RAW_ONLY)

            if baseName == "" then
                return
            end
            local exportCommand
            if fileType == ExportAction.EXPORT_SPRING_ARCHIVE then
                if isDir then
                    return false
                end

                self:ExportSpringArchive(path, heightmapExtremes)
                return true
            elseif fileType == ExportAction.EXPORT_MAP_TEXTURES then
                if isFile then
                    return false
                end

                self:TryToExportMapTextures(path, heightmapExtremes)
                return true
            elseif fileType == ExportAction.EXPORT_MAP_INFO then
                if isDir then
                    return false
                end

                Log.Notice("Exporting map info...")
                exportCommand = ExportMapInfoCommand(path)
            elseif fileType == ExportAction.EXPORT_S11N then
                if isDir then
                    return false
                end

                Log.Notice("Exporting s11n objects...")
                exportCommand = ExportS11NCommand(path)
            else
                Log.Error("Error trying to export. Invalid fileType specified: " .. tostring(fileType))
            end

            if exportCommand then
                SB.commandManager:execute(exportCommand, true)
                Log.Notice("Export complete.")
                return true
            end
        end
    )
end

local function CopyRecursively(src, dest, opts)
    opts = opts or {}
    Path.Walk(src, function(srcPath)
		local pathBase = srcPath:sub(#src + 2, #srcPath)

		Log.Notice("Copying " .. pathBase .. "...")
		local destPath = Path.Join(dest, pathBase)
		local destDir = Path.GetParentDir(destPath)
		Spring.CreateDir(destDir)

		local srcFileContent = VFS.LoadFile(srcPath, opts.mode)
		local destFile = assert(io.open(destPath, "w"))
		destFile:write(srcFileContent)
		destFile:close()
	end, opts)
end

local function WriteToFile(path, content)
    local file = assert(io.open(path, "w"))
    file:write(content)
    file:close()
end

ExportAction.NextStep = nil
function ExportAction:ExportSpringArchive(path, heightmapExtremes)
    Log.Notice("Exporting archive: " .. path .. ". This might take a while...")

    local buildDir = self:__CreateBuildDir()
    if not self:TryToExportMapTextures(buildDir, heightmapExtremes) then
        return
    end

    local archiveDir = Path.Join(buildDir, "archive")
    Spring.CreateDir(archiveDir)

    local luaGaiaDir = Path.Join(archiveDir, "LuaGaia")
    Spring.CreateDir(luaGaiaDir)

    WriteToFile(Path.Join(luaGaiaDir, "main.lua"), [[VFS.Include("LuaGadgets/gadgets.lua",nil, VFS.BASE)]])
    WriteToFile(Path.Join(luaGaiaDir, "draw.lua"), [[VFS.Include("LuaGadgets/gadgets.lua",nil, VFS.BASE)]])

    local gadgetsDir = Path.Join(luaGaiaDir, "Gadgets")
    Spring.CreateDir(gadgetsDir)

    local mapconfigDir = Path.Join(archiveDir, "mapconfig")
    Spring.CreateDir(mapconfigDir)

    local mapsDir = Path.Join(archiveDir, "maps")
    Spring.CreateDir(mapsDir)

    CopyRecursively("libs_sb/lcs",  Path.Join(archiveDir, "libs/lcs"),  { mode = VFS.ZIP })
    CopyRecursively("libs_sb/s11n", Path.Join(archiveDir, "libs/s11n"), { mode = VFS.ZIP })

    WriteToFile(Path.Join(gadgetsDir, "s11n_gadget_load.lua"),
        VFS.LoadFile("libs_sb/s11n/s11n_gadget_load.lua", VFS.ZIP))

    WriteToFile(Path.Join(gadgetsDir, "s11n_load_map_features.lua"),
        VFS.LoadFile("libs_sb/s11n/s11n_load_map_features.lua", VFS.ZIP):gsub(
            "local modelPath = nil", "local modelPath = \"mapconfig/s11n_model.lua\""))

    local cmds = {
        CompileMapCommand({
            heightPath = Path.Join(buildDir, "heightmap.png"),
            diffusePath = Path.Join(buildDir, "diffuse.png"),
            outputPath = Path.Join(SB_WRITE_PATH, mapsDir, SB.project.name)
        }),
        CopyCustomProjectFilesCommand(SB.project.path, archiveDir),
        ExportMapInfoCommand(Path.Join(archiveDir, "mapinfo.lua")),
        ExportS11NCommand(Path.Join(mapconfigDir, "s11n_model.lua")),
    }

    ExportAction.NextStep = function()
        Log.Notice("Do compound...")
        SB.commandManager:execute(CompoundCommand(cmds), true)

        ExportAction.NextStep = function()
            Log.Notice("Exporting archive: " .. path .. " ...")
            SB.commandManager:execute(ExportProjectCommand(archiveDir, path), true)

            Log.Notice("Deleting build directory...")
            SB.RemoveDirRecursively(buildDir)

            Log.Notice("Archive export complete")
            WG.Connector.Send("OpenFile", {
                path = "file://" .. Path.Join(SB_WRITE_PATH, Path.GetParentDir(path)),
            })

            ExportAction.NextStep = nil
        end
    end
end

function ExportAction:__CreateBuildDir()
    local i = 0
    local buildDir
    repeat
        i = i + 1
        buildDir = Path.Join(SB_EXPORTS_DIR, "__buildir_" .. tostring(i))
    until not SB.DirExists(buildDir)

    Spring.CreateDir(buildDir)
    return buildDir
end

function ExportAction:TryToExportMapTextures(path, heightmapExtremes)
    -- At least 5x the necessary amount? Super arbitrary...
    local wantedTexMemPoolSize = Game.mapSizeX / 1024 * Game.mapSizeZ / 1024 * 3 * 5
    local texMemPoolSize = Spring.GetConfigInt("TextureMemPoolSize", 0)
    if wantedTexMemPoolSize > texMemPoolSize then
        Dialog({
            message = "Texture pool size (" .. tostring(texMemPoolSize) ..
                       ") is too small to save the diffuse texture." ..
                      "\nDo you want to increase the pool size (to " ..
                      tostring(wantedTexMemPoolSize) .. ")?",
            ConfirmDialog = function()
                Spring.SetConfigInt("TextureMemPoolSize", wantedTexMemPoolSize)
                SB.AskToRestart()
            end,
        })
        return false
    end

    SB.commandManager:execute(ExportMapsCommand(path, heightmapExtremes), true)
    return true
end
