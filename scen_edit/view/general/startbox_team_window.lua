SB.Include(Path.Join(SB.DIRS.SRC, 'view/editor.lua'))

StartBoxTeamWindow = Editor:extends{}

function StartBoxTeamWindow:init(boxID, editorView)
    self:super("init")
	
    self.ID = boxID
	self.ev = editorView
    self:AddField(TeamField({
        name = self.ID,
        title = "Team: ",
        width = 300,
    }))

    local children = {}
    table.insert(children,
        ScrollPanel:New {
            x = 0,
            y = 0,
            bottom = 0,
            right = 0,
            borderColor = {0,0,0,0},
            horizontalScrollbar = false,
            children = { self.stackPanel },
        }
    )

    self:Finalize(children, {
        notMainWindow = true,
        buttons = { "close" },
    })

    table.insert(self.window.OnDispose, function()
        local newTeam = self.fields[self.ID].value
        local teamID = SB.model.startboxManager:setTeam(self.ID, newTeam)
		self.ev:Populate()
    end)
end