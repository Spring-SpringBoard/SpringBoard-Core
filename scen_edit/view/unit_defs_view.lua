UnitDefsView = LCS.class{}

function UnitDefsView:init()
    local updateAmount = function(obj, ...)
        local currentState = SCEN_EDIT.stateManager:GetCurrentState()
        if currentState:is_A(AddUnitState) then
            currentState.amount = self:GetAmount()
        end
    end
    self.ebAmount = EditBox:New {
        text = "1",
        x = 190 + 5,
        bottom = 8,
        width = 50,
        OnTextInput = {
            updateAmount
        },
        OnKeyPress = {
            updateAmount
        },
    }
    self.unitDefPanel = UnitDefsPanel:New {
        name='units',
        x = 0,
        right = 20,
        OnSelectItem = {
            function(obj,itemIdx,selected)
                if selected and itemIdx > 0 then
                    local currentState = SCEN_EDIT.stateManager:GetCurrentState()
                    if currentState:is_A(SelectUnitTypeState) then
                        local selUnitDef = self.unitDefPanel.items[itemIdx].id
                        currentState:SelectUnitType(selUnitDef)
                        self.unitDefPanel:SelectItem(0)
                    else
                        local selUnitDef = self.unitDefPanel.items[itemIdx].id
                        SCEN_EDIT.stateManager:SetState(AddUnitState(selUnitDef, self.unitDefPanel.teamId, self.unitDefPanel, self:GetAmount()))
                    end
                end
            end,
        },
    }
    local teamsCmb = ComboBox:New {
        bottom = 1,
        height = SCEN_EDIT.conf.B_HEIGHT,
        items = GetField(SCEN_EDIT.model.teamManager:getAllTeams(), "name"),
        playerTeamIds = GetField(SCEN_EDIT.model.teamManager:getAllTeams(), "id"),
        x = 40,
        width = 90,
    }
    teamsCmb.OnSelect = {
        function (obj, itemIdx, selected) 
            if selected then
                self.unitDefPanel:SelectTeamId(teamsCmb.playerTeamIds[itemIdx])
                local currentState = SCEN_EDIT.stateManager:GetCurrentState()
                if currentState:is_A(AddUnitState) then
                    currentState.teamId = self.unitDefPanel.teamId
                end
            end
        end
    }
    self.unitDefPanel:SelectTeamId(teamsCmb.playerTeamIds[teamsCmb.selected])
	
    self.window = Control:New {
--         parent = screen0,
--         caption = "Unit Editor",
--         width = 487,
--         height = 400,
--         resizable = false,
--         right = 10,
--         y = 500,
		x = 0,
		y = 0,
		bottom = 0,
		width = "100%",
        caption = '',
        children = {
            ScrollPanel:New {
                y = 15,
                x = 1,
                right = 1,
                bottom = SCEN_EDIT.conf.C_HEIGHT * 4,
                --horizontalScrollBar = false,
                children = {
                    self.unitDefPanel
                },
            },
            Label:New {
                x = 1,
                bottom = 8 + SCEN_EDIT.conf.C_HEIGHT * 2,
                caption = "Type:",
            },
            ComboBox:New {
                height = SCEN_EDIT.conf.B_HEIGHT,
                x = 40,
                bottom = 1 + SCEN_EDIT.conf.C_HEIGHT * 2,
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
                bottom = 8 + SCEN_EDIT.conf.C_HEIGHT * 2,
            },
            ComboBox:New {
				height = SCEN_EDIT.conf.B_HEIGHT,
				x = 190,
                bottom = 1 + SCEN_EDIT.conf.C_HEIGHT * 2,                
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
            Label:New {
                caption = "Team:",
                x = 1,
                bottom = 8,
            },
            teamsCmb,
			Label:New {
                caption = "Amount:",
                x = 140, 
                bottom = 8,
            },
			self.ebAmount,
			btnClose,
        }
    }
	SCEN_EDIT.view:SetMainPanel(self.window)
end

function UnitDefsView:GetAmount()
    return math.min(
        200,
        math.max(1, tonumber(self.ebAmount.text) or 1)
    )
end
