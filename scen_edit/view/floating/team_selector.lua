TeamSelector = LCS.class{}

function TeamSelector:init()
    local teams = SB.model.teamManager:getAllTeams()
    local teamsTxt = {}
    for _, team in pairs(teams) do
        table.insert(teamsTxt, SB.glToFontColor(team.color) .. "Team " .. team.name .. "\b")
    end
    table.insert(teamsTxt, "Spectator")
    self.cmbTeamSelector = ComboBox:New {
        parent = screen0,
        right = 501,
        y = 5,
        width = 200,
        height = 40,
        items = teamsTxt,
        font = { size = 16 },
        teamIDs = GetKeys(teams),
    }
    self.cmbTeamSelector.OnSelect = {
        function(_, itemIdx)
            if itemIdx < #teamsTxt then
                local teamID = self.cmbTeamSelector.teamIDs[itemIdx]
                if Spring.GetMyTeamID() ~= teamID or Spring.GetSpectatingState() then
                    if SB.FunctionExists(Spring.AssignPlayerToTeam, "Player change") then
                        local cmd = ChangePlayerTeamCommand(Spring.GetMyPlayerID(), teamID)
                        SB.commandManager:execute(cmd)
                    end
                end
            else
                if not Spring.GetSpectatingState() then
                    Spring.SendCommands("spectator")
                end
            end
        end
    }

    SB.lockTeam = false
    self.cbLockTeam = Checkbox:New {
        parent = screen0,
        x = self.cmbTeamSelector.x + 10,
        width = 90,
        y = 45,
        height = 20,
        caption = "Lock team",
        checked = false,
        OnChange = { function(_, value)
            SB.lockTeam = value
        end}
    }
end

function TeamSelector:Update()
    local selectedTeamID = self.cmbTeamSelector.teamIDs[self.cmbTeamSelector.selected]
    if not Spring.GetSpectatingState() and Spring.GetMyTeamID() ~= selectedTeamID then
        local OnSelect = self.cmbTeamSelector.OnSelect
        self.cmbTeamSelector.OnSelect = nil
        for i, teamID in pairs(self.cmbTeamSelector.teamIDs) do
            if teamID == Spring.GetMyTeamID() then
                self.cmbTeamSelector:Select(i)
                break
            end
        end
        self.cmbTeamSelector.OnSelect = OnSelect
    elseif Spring.GetSpectatingState() and selectedTeamID ~= nil then
        local OnSelect = self.cmbTeamSelector.OnSelect
        self.cmbTeamSelector.OnSelect = nil
        self.cmbTeamSelector:Select(#self.cmbTeamSelector.items)
        self.cmbTeamSelector.OnSelect = OnSelect
    end
end

function TeamSelector:DrawScreen()
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
        if SB.projectDir ~= nil then
            text = "Project:" .. SB.projectDir
        else
            text = "Project not saved"
        end
        local x = w - self.font:GetTextWidth(text) * fontSize - 10
        self.font:Print(text, x, y, 20, 'o')
    gl.PopMatrix()
end
