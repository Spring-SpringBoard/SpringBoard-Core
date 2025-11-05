--- RmlUi New Project Dialog

SB.Include(Path.Join(SB.DIRS.SRC, 'view/rmlui_dialogs/base_dialog.lua'))

RmlUiNewProjectDialog = RmlUiBaseDialog:extends{}

function RmlUiNewProjectDialog:init(opts)
    opts = opts or {}
    opts.rmlPath = Path.Join(SB.DIRS.SRC, 'view/rml/dialogs/new_project_dialog.rml')
    opts.title = "New Project"
    RmlUiBaseDialog.init(self, opts)
end

function RmlUiNewProjectDialog:Show()
    RmlUiBaseDialog.Show(self)

    if self.document then
        self:PopulateDropdowns()
        self:BindNewProjectEvents()
    end
end

function RmlUiNewProjectDialog:PopulateDropdowns()
    -- Populate map selector (stub)
    local mapSelect = self.document:GetElementById("map-select")
    if mapSelect then
        -- TODO: Get actual map list
        local mapsRml = [[
            <option value="map1">Example Map 1</option>
            <option value="map2">Example Map 2</option>
        ]]
        mapSelect.inner_rml = mapsRml
    end

    -- Populate game selector (stub)
    local gameSelect = self.document:GetElementById("game-select")
    if gameSelect then
        -- TODO: Get actual game list
        local gamesRml = [[
            <option value="game1">Example Game 1</option>
            <option value="game2">Example Game 2</option>
        ]]
        gameSelect.inner_rml = gamesRml
    end
end

function RmlUiNewProjectDialog:BindNewProjectEvents()
    local btnCreate = self.document:GetElementById("btn-create")
    if btnCreate then
        btnCreate:AddEventListener("click", function()
            self:CreateProject()
        end)
    end
end

function RmlUiNewProjectDialog:CreateProject()
    local projectName = self.document:GetElementById("project-name")
    local mapSelect = self.document:GetElementById("map-select")
    local gameSelect = self.document:GetElementById("game-select")
    local startType = self.document:GetElementById("start-type")

    if not projectName or not projectName.value or projectName.value == "" then
        Log.Warning("Project name is required")
        return
    end

    -- Stub: Create project
    Log.Notice("Creating project: " .. projectName.value)
    Log.Notice("Map: " .. (mapSelect and mapSelect.value or "none"))
    Log.Notice("Game: " .. (gameSelect and gameSelect.value or "none"))
    Log.Notice("Start type: " .. (startType and startType.value or "blank"))

    -- TODO: Actually create project
    if self.onConfirm then
        self.onConfirm({
            name = projectName.value,
            map = mapSelect and mapSelect.value,
            game = gameSelect and gameSelect.value,
            startType = startType and startType.value
        })
    end

    self:Close()
end
