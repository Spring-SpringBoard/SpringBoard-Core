UnitDefsView = LCS.class{}

function UnitDefsView:init()
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
                        SCEN_EDIT.stateManager:SetState(AddUnitState(selUnitDef, self.unitDefPanel.teamId, self.unitDefPanel))
                    end
                end
            end,
        },
    }
    local playerNames, playerTeamIds = GetTeams()
    local teamsCmb = ComboBox:New {
        bottom = 1,
        height = SCEN_EDIT.conf.B_HEIGHT,
        items = playerNames,
        playerTeamIds = playerTeamIds,
        x = 100,
        width=120,
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

    self.unitsWindow = Window:New {
        parent = screen0,
        caption = "Unit Editor",
        width = 487,
        height = 400,
        resizable = false,
        x = 1400,
        y = 500,
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
                width = 50,
                bottom = 8 + SCEN_EDIT.conf.C_HEIGHT * 2,
                caption = "Type:",
            },
            ComboBox:New {
                height = SCEN_EDIT.conf.B_HEIGHT,
                x = 50,
                bottom = 1 + SCEN_EDIT.conf.C_HEIGHT * 2,
                items = {
                    "Units", "Buildings", "All",
                },
                width = 80,
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
                width = 50,
            },
            ComboBox:New {
                bottom = 1 + SCEN_EDIT.conf.C_HEIGHT * 2,
                height = SCEN_EDIT.conf.B_HEIGHT,
                items = {
                    "Ground", "Air", "Water", "All",
                },
                x = 200,
                width=80,
                OnSelect = {
                    function (obj, itemIdx, selected) 
                        if selected then
                            self.unitDefPanel:SelectTerrainId(itemIdx)
                        end
                    end
                },
            },
            Label:New {
                caption = "Player:",
                x = 40,
                bottom = 8,
                width = 50,
            },
            teamsCmb,
        }
    }
end
