SCEN_EDIT.Include(SCEN_EDIT_VIEW_DIR .. "map_editor_view.lua")

UnitDefsView = MapEditorView:extends{}

function UnitDefsView:init()
    self:super("init")

    self.unitDefPanel = UnitDefsPanel({
        width = "100%",
        height = "100%"
    })
    self.unitDefPanel.control.OnSelectItem = {
        function(obj,itemIdx,selected)
            if selected and itemIdx > 0 then
                local currentState = SCEN_EDIT.stateManager:GetCurrentState()
                if currentState:is_A(SelectUnitTypeState) then
                    local selUnitDefID = self.unitDefPanel:GetUnitDefID(itemIdx)
                    currentState:SelectUnitType(selUnitDefID)
                    SCEN_EDIT.stateManager:SetState(DefaultState())
                else
                    local selUnitDefID = self.unitDefPanel:GetUnitDefID(itemIdx)
                    SCEN_EDIT.stateManager:SetState(AddUnitState(selUnitDefID, self.unitDefPanel, self))
                end
            end
        end
    }

    local children = {
        ScrollPanel:New {
            x = 1,
			right = 1,
			y = SCEN_EDIT.conf.C_HEIGHT * 4,
			height = "50%",
            --horizontalScrollBar = false,
            children = {
                self.unitDefPanel.control
            },
        },
        Label:New {
            x = 1,
            y = 8 + SCEN_EDIT.conf.C_HEIGHT * 2,
            caption = "Type:",
        },
        ComboBox:New {
            height = SCEN_EDIT.conf.B_HEIGHT,
            x = 40,
            y = 1 + SCEN_EDIT.conf.C_HEIGHT * 2,
            items = {
                "Units", "Buildings", "All",
            },
            width = 90,
            OnSelect = {
                function (obj, itemIdx, selected) 
                    if selected then
                        self.unitDefPanel:SelectUnitTypesId(itemIdx)
                    end
                end
            },
        },
        Label:New {
            caption = "Terrain:",
            x = 140,
            y = 8 + SCEN_EDIT.conf.C_HEIGHT * 2,
        },
        ComboBox:New {
            height = SCEN_EDIT.conf.B_HEIGHT,
            x = 190,
            y = 1 + SCEN_EDIT.conf.C_HEIGHT * 2,
            items = {
                "Ground", "Air", "Water", "All",
            },
            width = 90,
            OnSelect = {
                function (obj, itemIdx, selected) 
                    if selected then
                        self.unitDefPanel:SelectTerrainId(itemIdx)
                    end
                end
            },
        },
        btnClose,
    }

    self:AddNumericProperty({
        name = "amount", 
        title = "Amount:",
        tooltip = "Amount",
		value = 1,
        minValue = 1,
        maxValue = 100,
		step = 1,
    })

    local teamIds = GetField(SCEN_EDIT.model.teamManager:getAllTeams(), "id")
	for i = 1, #teamIds do
		teamIds[i] = tostring(teamIds[i])
	end
	local teamCaptions = GetField(SCEN_EDIT.model.teamManager:getAllTeams(), "name")
	self:AddChoiceProperty({
	    name = "team",
        items = teamIds,
		captions = teamCaptions,
        title = "Team: ",
    })
	self:UpdateChoiceField("team")

    table.insert(children, 
		ScrollPanel:New {
			x = 0,
			y = "65%",
			bottom = 30,
			right = 0,
			borderColor = {0,0,0,0},
			horizontalScrollbar = false,
			children = { self.stackPanel },
		}
	)

    self:Finalize(children)
end

function UnitDefsView:IsValidTest(state)
    return state:is_A(AddUnitState)
end
