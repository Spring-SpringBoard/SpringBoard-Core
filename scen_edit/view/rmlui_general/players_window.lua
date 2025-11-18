--- RmlUi Players Window

RmlUiPlayersWindow = RmlUiEditorBase:extends{}

function RmlUiPlayersWindow:init(model)
    self:super("init")
    self.model = model or PlayersWindowModel()
    self.editorTitle = "Teams"

    self.model:AddTeamListener(self)

    self:AddButton({
        caption = "Add Team",
        onClick = function()
            self.model:AddTeam()
        end
    })

    self:Populate()
end

function RmlUiPlayersWindow:Populate()
    -- TODO: Implement team list rendering in RmlUi
    -- For now this is a stub that would need proper RmlUi list implementation
end

function RmlUiPlayersWindow:onTeamAdded(teamID)
    self:Populate()
end

function RmlUiPlayersWindow:onTeamRemoved(teamID)
    self:Populate()
end

function RmlUiPlayersWindow:onTeamChange(teamID, team)
    self:Populate()
end
