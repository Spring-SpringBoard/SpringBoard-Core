
SCEN_EDIT_VIEW_DIR = SCEN_EDIT_DIR .. "view/"
SCEN_EDIT_VIEW_PANELS_DIR = SCEN_EDIT_VIEW_DIR .. "panels/"
SCEN_EDIT_VIEW_MAIN_WINDOW_DIR = SCEN_EDIT_VIEW_DIR .. "main_window/"
SCEN_EDIT_VIEW_ALLIANCE_DIR = SCEN_EDIT_VIEW_DIR .. "alliance/"
SCEN_EDIT_VIEW_ACTIONS_DIR = SCEN_EDIT_VIEW_DIR .. "actions/"

View = LCS.class{}

function View:init()
    SCEN_EDIT.Include(SCEN_EDIT_VIEW_DIR .. "view_area_manager_listener.lua")
    SCEN_EDIT.IncludeDir(SCEN_EDIT_VIEW_DIR)
    SCEN_EDIT.Include(SCEN_EDIT_VIEW_PANELS_DIR .. "abstract_type_panel.lua")
    SCEN_EDIT.IncludeDir(SCEN_EDIT_VIEW_PANELS_DIR)
	SCEN_EDIT.Include(SCEN_EDIT_VIEW_MAIN_WINDOW_DIR .. "abstract_main_window_panel.lua")
	SCEN_EDIT.IncludeDir(SCEN_EDIT_VIEW_MAIN_WINDOW_DIR)
	SCEN_EDIT.IncludeDir(SCEN_EDIT_VIEW_ALLIANCE_DIR)
	SCEN_EDIT.Include(SCEN_EDIT_VIEW_ACTIONS_DIR .. "abstract_action.lua")
	SCEN_EDIT.IncludeDir(SCEN_EDIT_VIEW_ACTIONS_DIR)
    SCEN_EDIT.clipboard = Clipboard()
    self.areaViews = {}
    if devMode then
        self.runtimeView = RuntimeView()
    end
    self.selectionManager = SelectionManager()
    self.displayDevelop = true
    --self.textureManager = TextureManager()
    --self.mainWindow = MainWindow()
	self.tabbedWindow = TabbedWindow()

    local teams = SCEN_EDIT.model.teamManager:getAllTeams()
    local teamsTxt = {}
    for _, team in pairs(teams) do
        table.insert(teamsTxt, SCEN_EDIT.glToFontColor(team.color) .. "Team " .. team.name .. "\b")
    end
    table.insert(teamsTxt, "Spectator")
    self.cmbTeamSelector = ComboBox:New {
        parent = screen0,
        right = 5,
        y = 5,
        width = 200,
        height = 40,
        items = teamsTxt,
        font = { size = 16 },
        teamIds = GetKeys(teams),
    }
    self.cmbTeamSelector.OnSelect = {
        function(_, itemIdx)
            if itemIdx < #teamsTxt then
                local teamId = self.cmbTeamSelector.teamIds[itemIdx]
                if Spring.GetMyTeamID() ~= teamId or Spring.GetSpectatingState() then
                    if SCEN_EDIT.FunctionExists(Spring.AssignPlayerToTeam, "Player change") then
                        local cmd = ChangePlayerTeamCommand(Spring.GetMyPlayerID(), teamId)
                        SCEN_EDIT.commandManager:execute(cmd)
                    end
                end
            else
                if not Spring.GetSpectatingState() then
                    Spring.SendCommands("spectator")
                end
            end
        end
    }

    SCEN_EDIT.lockTeam = false
    self.cbLockTeam = Checkbox:New {
        parent = screen0,
        x = self.cmbTeamSelector.x + 10,
        width = 90,
        y = 45,
        height = 20,
        caption = "Lock team",
        checked = false,
        OnChange = { function(_, value) 
            SCEN_EDIT.lockTeam = value
        end}
    }
end

function View:Update()
    local selectedTeamId = self.cmbTeamSelector.teamIds[self.cmbTeamSelector.selected]
    if not Spring.GetSpectatingState() and Spring.GetMyTeamID() ~= selectedTeamId then
        local OnSelect = self.cmbTeamSelector.OnSelect
        self.cmbTeamSelector.OnSelect = nil
        for i, teamId in pairs(self.cmbTeamSelector.teamIds) do
            if teamId == Spring.GetMyTeamID() then
                self.cmbTeamSelector:Select(i)
                break
            end
        end
        self.cmbTeamSelector.OnSelect = OnSelect
    elseif Spring.GetSpectatingState() and selectedTeamId ~= nil then
        local OnSelect = self.cmbTeamSelector.OnSelect
        self.cmbTeamSelector.OnSelect = nil
        self.cmbTeamSelector:Select(#self.cmbTeamSelector.items)
        self.cmbTeamSelector.OnSelect = OnSelect
    end
end

function View:drawRect(x1, z1, x2, z2)
    if x1 < x2 then
        _x1 = x1
        _x2 = x2
    else
        _x1 = x2
        _x2 = x1
    end
    if z1 < z2 then
        _z1 = z1
        _z2 = z2
    else
        _z1 = z2
        _z2 = z1 
    end
    gl.DrawGroundQuad(_x1, _z1, _x2, _z2)
end

function View:drawRects()
    gl.PushMatrix()
--    x, y = gl.GetViewSizes()
--    Spring.Echo(#self.areaViews)
    for _, areaView in pairs(self.areaViews) do
        areaView:Draw()
    end
    --[[
    for i, rect in pairs(SCEN_EDIT.model.areaManager:getAllAreas()) do
        if selected ~= i then
            gl.DrawGroundQuad(rect[1], rect[2], rect[3], rect[4])
        end
    end--]]
    --[[
    if selected ~= nil then
        gl.Color(0, 127, 127, 0.2)
        rect = SCEN_EDIT.model.areaManaget:getArea(selected)
        self:DrawRect(rect[1], rect[2], rect[3], rect[4])
    end--]]
    gl.PopMatrix()
end

function View:DrawWorld()
    --self.textureManager:DrawWorld()
end

function View:DrawWorldPreUnit()
    if self.displayDevelop then
        self:drawRects()
    end
    self.selectionManager:DrawWorldPreUnit()
end

function View:DrawScreen()
    gl.PushMatrix()
        local w, h = Spring.GetScreenGeometry()
        local fontSize = 20
        if self.font == nil then
            local fontName = "FreeSansBold.otf"
            self.font = gl.LoadFont(fontName, fontSize)
        end

        local y = 10
        local text
        local x = w - 200
        if SCEN_EDIT.projectDir ~= nil then
            text = "Project:" .. SCEN_EDIT.projectDir
        else
            text = "Project not saved"
        end
        local x = w - self.font:GetTextWidth(text) * fontSize - 10
        self.font:Print(text, x, y, 20, 'o')
    gl.PopMatrix()
end

function View:GameFrame(frameNum)
    self.selectionManager:GameFrame(frameNum)
end
