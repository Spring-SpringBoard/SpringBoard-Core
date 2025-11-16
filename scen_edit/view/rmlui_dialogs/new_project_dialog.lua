--- RmlUi New Project Dialog
--- 100% programmatic using AddField() - matches original Chili architecture

SB.Include(Path.Join(SB.DIRS.SRC, 'view/rmlui_dialogs/base_dialog.lua'))

RmlUiNewProjectDialog = RmlUiBaseDialog:extends{}

function RmlUiNewProjectDialog:init(opts)
    opts = opts or {}
    opts.title = "New Project"
    self:super("init", opts)

    -- Add fields programmatically (like original Chili version)
    self:AddField(StringField({
        name = "projectName",
        title = "Project name:",
        value = "",
        width = 300,
    }))

    -- TODO: Get actual maps without projects
    local items = {"SB_Blank_Map", "Example Map 1", "Example Map 2"}
    local captions = {"Blank", "Example Map 1", "Example Map 2"}

    self:AddField(ChoiceField({
        name = "mapName",
        title = "Map:",
        items = items,
        captions = captions,
        width = 300,
    }))

    self:AddField(GroupField({
        fields = {
            NumericField({
                name = "sizeX",
                title = "Size X:",
                width = 140,
                min = 2,
                max = 32,
                step = 2,
                value = 10,
            }),
            NumericField({
                name = "sizeY",
                title = "Size Y:",
                width = 140,
                min = 2,
                max = 32,
                step = 2,
                value = 10,
            })
        }
    }))

    -- Error message field
    self:AddField(StringField({
        name = "error",
        title = "",
        value = "",
        width = 400,
    }))
end

function RmlUiNewProjectDialog:SetDialogError(error)
    if error ~= nil then
        self:SetFieldValue("error", tostring(error))
    else
        self:SetFieldValue("error", "Unknown error")
    end
end

function RmlUiNewProjectDialog:ConfirmDialog()
    -- Validation logic (matching original Chili version)
    self:SetDialogError("")

    local projectName = self:GetFieldValue("projectName")
    if not projectName or String.Trim(projectName) == "" then
        self:SetDialogError("Missing project name.")
        return false
    end

    local mapName = self:GetFieldValue("mapName")
    if mapName == "SB_Blank_Map" then
        local sizeX = self:GetFieldValue("sizeX")
        local sizeY = self:GetFieldValue("sizeY")

        if sizeX % 2 ~= 0 then
            self:SetDialogError("sizeX must be an even number.")
            return false
        end

        if sizeY % 2 ~= 0 then
            self:SetDialogError("sizeY must be an even number.")
            return false
        end

        -- TODO: Set up blank map generation
        Log.Notice("Creating blank map project: " .. projectName .. " (" .. sizeX .. "x" .. sizeY .. ")")
    else
        Log.Notice("Creating project: " .. projectName .. " with map: " .. mapName)
    end

    -- TODO: Actually create project
    return true
end

function RmlUiNewProjectDialog:OnFieldChange(name, value)
    -- Hide/show size fields based on map selection
    if name == "mapName" then
        if value == "SB_Blank_Map" then
            -- TODO: Show sizeX/sizeY fields
            Log.Debug("Show blank map size fields")
        else
            -- TODO: Hide sizeX/sizeY fields
            Log.Debug("Hide blank map size fields")
        end
    end
end
