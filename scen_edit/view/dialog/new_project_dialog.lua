SB.Include(Path.Join(SB.DIRS.SRC, 'view/editor.lua'))

NewProjectDialog = Editor:extends{}

local GeMapsWithoutProjects

function NewProjectDialog:init()
    self:super("init")

    self:AddField(StringField({
        name = "projectName",
        title = "Project name:",
        width = 300,
    }))

    local items = GeMapsWithoutProjects()
    table.insert(items, 1, "SB_Blank_Map")
    local captions = Table.DeepCopy(items)
    captions[1] = "Blank"
    self:AddField(ChoiceField({
        name = "mapName",
        title = "Map:",
        items = items,
        captions = captions,
        width = 300,
    }))

    self:AddField(GroupField({
        NumericField({
            name = "sizeX",
            title = "Size X:",
            width = 140,
            minValue = 2,
            value = 10,
            maxValue = 32,
            step = 2,
            decimals = 0,
        }),
        NumericField({
            name = "sizeY",
            title = "Size Y:",
            width = 140,
            minValue = 1,
            value = 10,
            maxValue = 32,
            step = 2,
            decimals = 0,
        })
    }))

    self.error = Label:New {
        font = {
            color = { 1, 0, 0, 1 },
        },
        caption = ""
    }
    self:AddControl('error', { self.error })

    local children = {
        ScrollPanel:New {
            x = 0,
            y = 0,
            bottom = 30,
            right = 0,
            borderColor = {0,0,0,0},
            horizontalScrollbar = false,
            children = { self.stackPanel },
        },
    }

    self:Finalize(children, {
        notMainWindow = true,
        buttons = { "ok", "cancel" },
        width = 400,
        height = 300,
    })
end

function NewProjectDialog:SetDialogError(error)
    if error ~= nil then
        self.error:SetCaption(tostring(error))
    else
        self.error:SetCaption('Unknown error')
    end
end

function NewProjectDialog:ConfirmDialog()
    self:SetDialogError("")
    local projectName = self.fields["projectName"].value
    if String.Trim(projectName) == "" then
        SB.HintControls(self.fields["projectName"].components)
        self:SetDialogError("Missing project name.")
        return
    end

    SB.project.mutators = { projectName .. " 1.0" }
    if self.fields["mapName"].value == "SB_Blank_Map" then
        if self.fields["sizeX"].value % 2 ~= 0 then
            SB.HintControls(self.fields["sizeX"].components)
            self:SetDialogError("sizeX must be an even number.")
            return
        end

        if self.fields["sizeY"].value % 2 ~= 0 then
            SB.HintControls(self.fields["sizeY"].components)
            self:SetDialogError("sizeY must be an even number.")
            return
        end
        -- We add a randomly generated name to the project prefix to avoid this bug
        -- Caching of generated maps:
        -- 1. Make a project named "test" of size 4x4
        -- 2. Delete project while in same Spring
        -- 3. Make a project named "test" of size 3x5
        -- 4. Expected: New project of 3x5 will be loaded. Actual: Project of 4x4 will be loaded.
        -- A. Quitting Spring after step 3. and loading test will properly load the 3x5 project.
        SB.project.mapName = "blank_"  .. tostring(math.random(1, 1000000)) .. projectName .. " 1.0"
        SB.project.randomMapOptions = {
            mapSeed = 1,
            new_map_x = self.fields["sizeX"].value,
            new_map_y = self.fields["sizeY"].value,
        }
    else
        SB.project.mapName = self.fields.mapName.value
    end

    local _, path = Project.GenerateNamePath(projectName)
    if SB.DirExists(path) then
        SB.HintControls(self.fields["projectName"].components)
        self:SetDialogError("Project \"" .. tostring(projectName) .. "\" already exists.")
        return
    end

    SB.project:GenerateNewProjectInfo(projectName)
    local cmd = ReloadIntoProjectCommand(SB.project.path, false)
    SB.commandManager:execute(cmd, true)
end

function NewProjectDialog:OnFieldChange(name, value)
    if name == "mapName" then
        if value == "SB_Blank_Map" then
            self:SetInvisibleFields()
        else
            self:SetInvisibleFields("sizeX", "sizeY")
        end
    end
end

GeMapsWithoutProjects = function()
    local projectMaps = {}
    for _, folder in pairs(Path.SubDirs(SB.DIRS.PROJECTS, "*", VFS.RAW)) do
        if Project.IsDirProject(folder) then
            local projectInfoPath = Path.Join(folder, Project.PROJECT_FILE)
            if VFS.FileExists(projectInfoPath, VFS.RAW) then
                local projectInfo = VFS.Include(projectInfoPath, nil, VFS.RAW)
                local mutator = projectInfo.mutators[1]
                if mutator ~= nil then
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
        -- FIXME: Spring doesn't properly detect when archives have been deleted
        -- will return true even after deleting them. A restart is necessary
        -- neither VFS.ScanAllDirs() nor manually checking with VFS.HasArchive helps
        if not projectMaps[map] and not unique[map] and VFS.HasArchive(map) then
            table.insert(filtered, map)
            unique[map] = true
        end
    end
    return filtered
end