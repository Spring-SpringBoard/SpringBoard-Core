NewProjectDialogModel = LCS.class{}

function NewProjectDialogModel:init()
    self.listeners = {}
end

function NewProjectDialogModel:AddListener(listener)
    table.insert(self.listeners, listener)
end

function NewProjectDialogModel:NotifyListeners(event, ...)
    for _, listener in ipairs(self.listeners) do
        if listener[event] then
            listener[event](listener, ...)
        end
    end
end

function NewProjectDialogModel:GetMapsWithoutProjects()
    local projectMaps = {}
    for _, folder in pairs(Path.SubDirs(SB.DIRS.PROJECTS, "*", VFS.RAW)) do
        if Project.IsDirProject(folder) then
            local projectInfoPath = Path.Join(folder, Project.PROJECT_FILE)
            if VFS.FileExists(projectInfoPath, VFS.RAW) then
                local projectInfo = VFS.Include(projectInfoPath, nil, VFS.RAW)
                local mutator = projectInfo.mutators[1]
                if mutator then
                    projectMaps[mutator] = true
                end
            end
        end
    end

    local maps = VFS.GetMaps()
    local filtered = {}
    local unique = {}
    VFS.ScanAllDirs()
    for _, map in ipairs(maps) do
        if not projectMaps[map] and not unique[map] and VFS.HasArchive(map) then
            table.insert(filtered, map)
            unique[map] = true
        end
    end
    return filtered
end

function NewProjectDialogModel:GetMapItems()
    local items = self:GetMapsWithoutProjects()
    table.insert(items, 1, "SB_Blank_Map")
    local captions = Table.DeepCopy(items)
    captions[1] = "Blank"
    return items, captions
end

function NewProjectDialogModel:ValidateProjectName(projectName)
    if String.Trim(projectName) == "" then
        return false, "Missing project name."
    end

    local _, path = Project.GenerateNamePath(projectName)
    if SB.DirExists(path) then
        return false, "Project \"" .. tostring(projectName) .. "\" already exists."
    end

    return true
end

function NewProjectDialogModel:ValidateMapSize(sizeX, sizeY)
    if sizeX % 2 ~= 0 then
        return false, "sizeX must be an even number."
    end

    if sizeY % 2 ~= 0 then
        return false, "sizeY must be an even number."
    end

    return true
end

function NewProjectDialogModel:CreateProject(projectName, mapName, sizeX, sizeY)
    local valid, error = self:ValidateProjectName(projectName)
    if not valid then
        return false, error
    end

    if mapName == "SB_Blank_Map" then
        valid, error = self:ValidateMapSize(sizeX, sizeY)
        if not valid then
            return false, error
        end

        -- Random name to avoid caching issues
        SB.project.mapName = "blank_" .. tostring(math.random(1, 1000000)) .. projectName .. " 1.0"
        SB.project.randomMapOptions = {
            mapSeed = 1,
            new_map_x = sizeX,
            new_map_y = sizeY,
        }
    else
        SB.project.mapName = mapName
    end

    SB.project:GenerateNewProjectInfo(projectName)
    local cmd = ReloadIntoProjectCommand(SB.project.path, false)
    SB.commandManager:execute(cmd, true)

    return true
end

function NewProjectDialogModel:ShouldShowSizeFields(mapName)
    return mapName == "SB_Blank_Map"
end
