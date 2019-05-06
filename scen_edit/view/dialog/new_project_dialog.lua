SB.Include(Path.Join(SB_VIEW_DIR, "editor.lua"))

NewProjectDialog = Editor:extends{}

function NewProjectDialog:init()
    self:super("init")

    self:AddField(StringField({
        name = "projectName",
        title = "Project name:",
        width = 300,
    }))

    local items = VFS.GetMaps()
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
            minValue = 1,
            value = 5,
            maxValue = 32,
        }),
        NumericField({
            name = "sizeZ",
            title = "Size Z:",
            width = 140,
            minValue = 1,
            value = 5,
            maxValue = 32,
        })
    }))

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
        height = 200,
    })
end

function NewProjectDialog:ConfirmDialog()
    local projectName = self.fields["projectName"].value
    if String.Trim(projectName) == "" then
        SB.HintControls(self.fields["projectName"].components)
        return
    end

    SB.project.mutators = { projectName .. " 1.0" }
    if self.fields["mapName"].value == "SB_Blank_Map" then
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
            new_map_z = self.fields["sizeZ"].value,
        }
    else
        SB.project.mapName = self.fields.mapName.value
    end

    local _, path = Project.GenerateNamePath(projectName)
    if SB.DirExists(path) then
        SB.HintControls(self.fields["projectName"].components)
        Log.Error("Project \"" .. tostring(projectName) .. "\" already exists.")
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
            self:SetInvisibleFields("sizeX", "sizeZ")
        end
    end
end
