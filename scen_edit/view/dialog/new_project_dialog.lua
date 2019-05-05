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

    if self.fields["mapName"].value == "SB_Blank_Map" then
        SB.project.mapName = "blank_" .. projectName .. " 1.0"
        SB.project.randomMapOptions = {
            mapSeed = 1,
            new_map_x = self.fields["sizeX"].value,
            new_map_z = self.fields["sizeZ"].value,
        }
        SB.project.mutators = {
            projectName .. " 1.0"
        }
    else
        SB.project.mapName = self.fields.mapName.value
    end

    SB.project:SaveProjectInfo(projectName)
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
