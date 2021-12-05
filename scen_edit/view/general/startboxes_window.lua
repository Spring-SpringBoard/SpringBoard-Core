SB.Include(Path.Join(SB.DIRS.SRC, 'view/editor.lua'))

StartBoxWindow = Editor:extends{}
StartBoxWindow:Register({
    name = "startboxWindow",
    tab = "Misc",
    caption = "StartBox",
    tooltip = "Edit areas",
    image = Path.Join(SB.DIRS.IMG, 'bolivia.png'),
    order = 2,
})

function StartBoxWindow:init()
    self:super("init")
    self.btnAddArea = TabbedPanelButton({
        x = 0,
        y = 0,
        tooltip = "Add area",
        children = {
            TabbedPanelImage({ file = Path.Join(SB.DIRS.IMG, 'area-add.png') }),
            TabbedPanelLabel({ caption = "Add" }),
        },
        OnClick = {
            function()
				self.type = "add"
                SB.stateManager:SetState(AddStartBoxState(self))
            end
        },
    })
    self:AddDefaultKeybinding({
        self.btnAddArea
    })

    self.areasPanel = StackPanel:New {
        itemMargin = {0, 0, 0, 0},
        width = "100%",
        autosize = true,
        resizeItems = false,
    }
    local children = {
        ScrollPanel:New {
            x = 0,
            y = 80,
            bottom = 30,
            right = 0,
            borderColor = {0,0,0,0},
            horizontalScrollbar = false,
            children = {
                self.areasPanel
            },
        },
        self.btnAddArea,
    }

    self:Populate()
    local startboxManagerListener = StartBoxManagerListenerWidget(self)
    SB.model.startboxManager:addListener(startboxManagerListener)
    self:Finalize(children)
end

function StartBoxWindow:__OnShow()
	SB.stateManager:SetState(ViewStartBoxState(self))
end

function StartBoxWindow:Populate()
	SB.stateManager:SetState(ViewStartBoxState(self))
    self.areasPanel:ClearChildren()
	self:AddField(TeamField({
        name = "team",
        title = "Team: ",
        width = 300,
	}))
    local areas = SB.model.startboxManager:getAllRawStartBoxes()
    for ID, _ in pairs(areas) do
		local teamID = SB.model.startboxManager:getTeam(ID)
		if teamID then
			local team = SB.model.teamManager:getTeam(teamID)
			local fontColor = SB.glToFontColor(team.color)
			teamstr = fontColor .. team.name .. "\b"
		else 
			teamstr = "Select Team"
		end
        local areaStackPanel = MakeComponentPanel(self.areasPanel)
        areaStackPanel.areaID = ID
        local lblArea = Label:New {
            caption = "Area ID: " .. tostring(ID),
            right = SB.conf.B_HEIGHT + 10,
            x = 1,
            height = SB.conf.B_HEIGHT,
            _toggle = nil,
            parent = areaStackPanel,
        }
		local btnEditTeam = Button:New {
            caption = teamstr,
            right = SB.conf.B_HEIGHT + 100,
            width = 160,
            height = SB.conf.B_HEIGHT,
            parent = areaStackPanel,
            padding = {0, 0, 0, 0},
			OnClick = {
				function()
					local startboxteamWindow = StartBoxTeamWindow(ID, self)
					startboxteamWindow.window.x = self.window.x + self.window.width
					startboxteamWindow.window.y = self.window.y
				end
			},
		}
		local btnMirrorBox = Button:New {
            caption = "Mirror",
            right = SB.conf.B_HEIGHT + 40,
            width = 60,
            height = SB.conf.B_HEIGHT,
            parent = areaStackPanel,
            padding = {0, 0, 0, 0},
			OnClick = {
				function()
					SB.model.startboxManager:addMirroredBox(ID)
				end
			},
		}
        local btnRemoveArea = Button:New {
            caption = "",
            right = 0,
            width = SB.conf.B_HEIGHT,
            height = SB.conf.B_HEIGHT,
            parent = areaStackPanel,
            padding = {2, 2, 2, 2},
            tooltip = "Remove area",
            classname = "negative_button",
            children = {
                Image:New {
                    file = Path.Join(SB.DIRS.IMG, 'cancel.png'),
                    height = "100%",
                    width = "100%",
                },
            },
            OnClick = {
                function()
					SB.model.startboxManager:removeBox(ID)
                end
            },
        }
    end
end

function StartBoxWindow:IsValidState(state)
    return state:is_A(AddStartBoxState)
end

function StartBoxWindow:OnLeaveState(state)
	if state:is_A(AddStartBoxState) then
		for _, btn in pairs({self.btnAddArea}) do
			btn:SetPressedState(false)
		end
	end
end

function StartBoxWindow:OnEnterState(state)
	if state:is_A(AddStartBoxState) then
		for _, btn in pairs({self.btnAddArea}) do
			btn:SetPressedState(true)
		end
	end
end

StartBoxManagerListenerWidget = StartBoxManagerListener:extends{}

function StartBoxManagerListenerWidget:init(areaWindow)
    self.window = areaWindow
end

function StartBoxManagerListenerWidget:onBoxAdded(areaID)
	SB.delay(function()
    SB.delay(function()
    SB.delay(function()
    self.window:Populate()end)end)end)
end

function StartBoxManagerListenerWidget:onBoxRemoved(areaID)
	SB.delay(function()
    SB.delay(function()
    SB.delay(function()
    self.window:Populate()end)end)end)
end

function StartBoxManagerListenerWidget:onBoxChange(areaID, area)
end
