SB.Include(Path.Join(SB.DIRS.SRC, 'view/actions/action.lua'))

ExportAction = Action:extends{}

ExportAction:Register({
    name = "sb_export",
    tooltip = "Export",
    image = Path.Join(SB.DIRS.IMG, 'save.png'),
    toolbar_order = 6,
    hotkey = {
        key = KEYSYMS.E,
        ctrl = true
    }
})

ExportAction.EXPORT_SPRING_ARCHIVE = "Spring archive"
ExportAction.EXPORT_MAP_TEXTURES = "Map textures"
ExportAction.EXPORT_HEIGHTMAP = "Heightmap (16-bit PNG)"
ExportAction.EXPORT_MAP_INFO = "Map info"
ExportAction.EXPORT_S11N = "s11n object format"
local fileTypes = {
    ExportAction.EXPORT_SPRING_ARCHIVE,
    ExportAction.EXPORT_MAP_TEXTURES,
    ExportAction.EXPORT_HEIGHTMAP,
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
        SB.NotifyWarn("export_warn", "The project must be saved before exporting")
        return false
    end
    return true
end

function ExportAction:CheckHasSaved()
    local projectFiles = {
        Path.Join(SB.project.path, Project.HEIGHTMAP_FILE),
        Path.Join(SB.project.path, Project.MODEL_FILE),
        Path.Join(SB.project.path, Project.GRASS_FILE),
        Path.Join(SB.project.path, Project.METAL_FILE)
    }

    for _, projectFile in ipairs(projectFiles) do
        if not VFS.FileExists(projectFile, VFS.RAW) then
            SB.NotifyWarn("export_warn", "The project must be saved before exporting")
            return false
        end
    end

    return true
end

function ExportAction:execute()
    ExportFileDialog(SB.DIRS.EXPORTS, fileTypes):setConfirmDialogCallback(
        function(path, fileType, heightmapExtremes)
            local baseName = Path.ExtractFileName(path)
            local isFile = VFS.FileExists(path, VFS.RAW)
            local isDir = SB.DirExists(path, VFS.RAW)

            if baseName == "" then
                return
            end
            local exportCommand
            if fileType == ExportAction.EXPORT_SPRING_ARCHIVE then
                if isDir then
                    return false, "Please select a file"
                end

                if not self:CheckHasSaved() then
                    return false, "Project files missing. Save before exporting"
                end

                self:ExportSpringArchive(path, heightmapExtremes)
                return true
            elseif fileType == ExportAction.EXPORT_MAP_TEXTURES then
                if isFile then
                    return false, "Please select a directory"
                end

                if not self:CheckHasSaved() then
                    return false, "Project files missing. Save before exporting"
                end

                local progressID = SB.GenerateNotificationID()
                SB.ActionProgress(progressID, 0.1, "Exporting maps textures...")
                SB.delay(function()
                    self:TryToExportMapTextures(path, heightmapExtremes):next(function()
                        SB.ActionProgress(progressID, 1.0, "Exporting maps textures: Finished")
                    end)
                end)
                return true
            elseif fileType == ExportAction.EXPORT_HEIGHTMAP then
                if isDir then
                    return false, "Please select a file"
                end

                -- The image crate infers the format from the extension; default
                -- to .png when none is given. (Path.GetExt returns the whole name
                -- for extensionless paths, so test the filename for a dot.)
                if not string.find(Path.ExtractFileName(path), "%.") then
                    path = path .. ".png"
                end

                Log.Notice("Exporting heightmap to " .. path .. " ...")
                -- Native (Rust) command: dispatch to the gadget (not widget) so
                -- the native module runs it. It reads the live heightmap and
                -- writes the 16-bit PNG directly — no launcher, no saved project.
                -- min/max come from the dialog's "Heightmap extremes" so the
                -- range matches what you enter on import.
                SB.commandManager:execute(ExportHeightmapCommand(path, heightmapExtremes))
                Log.Notice("Export complete.")
                return true
            elseif fileType == ExportAction.EXPORT_MAP_INFO then
                if isDir then
                    return false, "Please select a file"
                end

                Log.Notice("Exporting map info...")
                exportCommand = ExportMapInfoCommand(path)
            elseif fileType == ExportAction.EXPORT_S11N then
                if isDir then
                    return false, "Please select a file"
                end

                Log.Notice("Exporting s11n objects...")
                exportCommand = ExportS11NCommand(path)
            else
                Log.Error("Error trying to export. Invalid fileType specified: " .. tostring(fileType))
                return false, "Internal error. Invalid fileType specified: " .. tostring(fileType)
            end

            if exportCommand then
                SB.commandManager:execute(exportCommand, true)
                Log.Notice("Export complete.")
                return true
            end
        end
    )
end

-- TODO: duplicate of copy_custom_project_files_command.lua
local ignoredFiles = {
	[".git"] = true
}

local function CopyFile(src, dest, mode)
    local srcFileContent = VFS.LoadFile(src, mode)
    local destFile = assert(io.open(dest, "wb"))
    destFile:write(srcFileContent)
    destFile:close()
end

local function CopyRecursively(src, dest, opts)
    opts = opts or {}
    Path.Walk(src, function(srcPath)
        local pathBase = srcPath:sub(#src + 2, #srcPath)

        if ignoredFiles[Path.ExtractFileName(pathBase)] then
            return
        end

		Log.Notice("Copying " .. pathBase .. "...")
		local destPath = Path.Join(dest, pathBase)
		local destDir = Path.GetParentDir(destPath)
		Spring.CreateDir(destDir)

        CopyFile(srcPath, destPath, opts.mode)
	end, opts)
end

local function WriteToFile(path, content)
    local file = assert(io.open(path, "w"))
    file:write(content)
    file:close()
end

function ExportAction:ExportSpringArchive(path, heightmapExtremes)
    local progressID = SB.GenerateNotificationID()
    SB.ActionProgress(progressID, 0.0, "Exporting archive...")
    Log.Notice("Exporting archive: " .. path .. ". This might take a while...")
    SB.compileMapProgressID = progressID

    SB.commandManager:executeNativeAsync(ExportSpringArchiveCommand(path, heightmapExtremes)):next(function()
        Log.Notice("Archive export complete")
        local exportDir = Path.GetParentDir(path)
        if SB.DIRS.WRITE_PATH then
            exportDir = Path.Join(SB.DIRS.WRITE_PATH, exportDir)
        end
        WG.Connector.Send("OpenFile", {
            path = "file://" .. exportDir,
        })
        SB.ActionProgress(progressID, 1.0, "Exporting archive: Finished.")
        SB.compileMapProgressID = nil
    end):catch(function(reason)
        Log.Error("Export action failed: " .. tostring(reason))
        SB.compileMapProgressID = nil
    end)
end

function ExportAction:TryToExportMapTextures(path, heightmapExtremes)
    -- At least 5x the necessary amount? Super arbitrary...
    local wantedTexMemPoolSize = Game.mapSizeX / 1024 * Game.mapSizeZ / 1024 * 3 * 5
    local texMemPoolSize = Spring.GetConfigInt("TextureMemPoolSize", 0)
    if wantedTexMemPoolSize > texMemPoolSize then
        Dialog({
            caption = "Texture pool size",
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

    return SB.commandManager:executeNativeAsync(ExportMapsCommand(path, heightmapExtremes))
end
