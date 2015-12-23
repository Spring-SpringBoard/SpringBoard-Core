SCEN_EDIT.Include(SCEN_EDIT_VIEW_DIR .. "map_editor_view.lua")

FeatureDefsView = MapEditorView:extends{}

function FeatureDefsView:init()
	self:super("init")

    self.featureDefsPanel = FeatureDefsPanel:New {
        name='features',
        x = 0,
        right = 20,
        OnSelectItem = {
            function(obj,itemIdx,selected)
                if selected and itemIdx > 0 then
                    local currentState = SCEN_EDIT.stateManager:GetCurrentState()
                    if currentState:is_A(SelectFeatureTypeState) then
                        selFeatureDef = self.featureDefsPanel.items[itemIdx].id
                        CallListeners(currentState.btnSelectType.OnSelectFeatureType, selFeatureDef)
                        SCEN_EDIT.stateManager:SetState(DefaultState())
                    else
                        selFeatureDef = self.featureDefsPanel.items[itemIdx].id
                        SCEN_EDIT.stateManager:SetState(AddFeatureState(selFeatureDef, self.featureDefsPanel, self))
                    end
                    local feature = FeatureDefs[selFeatureDef]
                end
            end,
        },
    }
	
	local children = {
		ScrollPanel:New {
			x = 1,
			right = 1,
			y = SCEN_EDIT.conf.C_HEIGHT * 4,
			height = "30%",
			--horizontalScrollBar = false,
			children = {
				self.featureDefsPanel
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
				"Wreckage", "Other", "All",
			},
			width = 90,
			OnSelect = {
				function (obj, itemIdx, selected) 
					if selected then
						self.featureDefsPanel:SelectFeatureTypesId(itemIdx)
					end
				end
			},
		},
		Label:New {
			x = 140,
			y = 8 + SCEN_EDIT.conf.C_HEIGHT * 2,
			caption = "Wreck:",
		},
		ComboBox:New {
			height = SCEN_EDIT.conf.B_HEIGHT,
			x = 190,
			y = 1 + SCEN_EDIT.conf.C_HEIGHT * 2,
			items = {
				"Units", "Buildings", "All",
			},
			width = 90,
			OnSelect = {
				function (obj, itemIdx, selected) 
					if selected then
						self.featureDefsPanel:SelectUnitTypesId(itemIdx)
					end
				end
			},
		},
		Label:New {
			caption = "Terrain:",
			x = 290,
			y = 8 + SCEN_EDIT.conf.C_HEIGHT * 2,
		},
		ComboBox:New {
			y = 1 + SCEN_EDIT.conf.C_HEIGHT * 2,
			height = SCEN_EDIT.conf.B_HEIGHT,
			items = {
				"Ground", "Air", "Water", "All",
			},
			x = 340,
			width = 90,
			OnSelect = {
				function (obj, itemIdx, selected) 
					if selected then
						self.featureDefsPanel:SelectTerrainId(itemIdx)
					end
				end
			},
		},
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
			y = "45%",
			bottom = 30,
			right = 0,
			borderColor = {0,0,0,0},
			horizontalScrollbar = false,
			children = { self.stackPanel },
		}
	)
	self:Finalize(children)
end

function FeatureDefsView:IsValidTest(state)
    return state:is_A(AddFeatureState)
end