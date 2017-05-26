SB.Include(Path.Join(SB_VIEW_DIR, "editor_view.lua"))

ScenarioInfoView = EditorView:extends{}

function ScenarioInfoView:init()
	self:super("init")

	self:AddField(
		StringField({
            name = "name",
            title = "Name:",
            width = 200,
			value = SB.model.scenarioInfo.name,
        })
    )

	self:AddField(
		StringField({
			name = "description",
			title = "Description:",
			width = 200,
			value = SB.model.scenarioInfo.description,
		})
	)

	self:AddField(
		StringField({
            name = "version",
            title = "Version:",
            width = 200,
			value = tostring(SB.model.scenarioInfo.version),
        })
    )

	self:AddField(
		StringField({
            name = "author",
            title = "Author:",
            width = 200,
			value = SB.model.scenarioInfo.author,
        })
    )

	local children = {
        ScrollPanel:New {
            x = 0,
            y = 0,
            bottom = 10,
            right = 0,
            borderColor = {0,0,0,0},
            horizontalScrollbar = false,
            children = { self.stackPanel },
        },
    }

	self:Finalize(children)
end

function ScenarioInfoView:OnFieldChange(name, value)
	local cmd = SetScenarioInfoCommand(
		self.fields['name'].value, self.fields['description'].value,
		self.fields['version'].value, self.fields['author'].value)
    SB.commandManager:execute(cmd)
end
