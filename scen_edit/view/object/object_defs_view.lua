SB.Include(Path.Join(SB_VIEW_DIR, "editor_view.lua"))

ObjectDefsView = EditorView:extends{}

function ObjectDefsView:init()
    self:super("init")

    self.btnBrush = TabbedPanelButton({
        x = 0,
        y = 0,
        tooltip = "Add or remove objects by painting the map",
        children = {
            TabbedPanelImage({ file = SB_IMG_DIR .. "object-brush-add.png" }),
            TabbedPanelLabel({ caption = "Brush" }),
        },
        OnClick = {
            function()
                self.type = "brush"
                self:EnterState()
            end
        },
    })
    self.btnSet = TabbedPanelButton({
        x = 70,
        y = 0,
        tooltip = "Add objects by clicking on the map",
        children = {
            TabbedPanelImage({ file = SB_IMG_DIR .. "object-set-add.png" }),
            TabbedPanelLabel({ caption = "Add" }),
        },
        OnClick = {
            function()
                self.type = "set"
                self:EnterState()
            end
        },
    })

    self:MakePanel({
        ctrl = {
            x = 0,
            right = 0,
            y = 150,
            bottom = "35%", -- 100 - 65
        }
    })
    self.objectDefPanel.OnSelectItem = {
        function(item, selected)
            if #self.objectDefPanel:GetSelectedObjectDefs() > 0 then
                self:EnterState()
            else
                SB.stateManager:SetState(DefaultState())
            end
        end
    }
    self:MakeFilters()

    local teamIDs = GetField(SB.model.teamManager:getAllTeams(), "id")
	for i = 1, #teamIDs do
		teamIDs[i] = tostring(teamIDs[i])
	end
	local teamCaptions = GetField(SB.model.teamManager:getAllTeams(), "name")
	self:AddField(ChoiceField({
	    name = "team",
        items = teamIDs,
		captions = teamCaptions,
        title = "Team: ",
    }))
	self:Update("team")
    self:AddField(NumericField({
        name = "amount",
        title = "Amount:",
        tooltip = "Amount",
        value = 1,
        minValue = 1,
        maxValue = 100,
        step = 1,
        decimals = 0,
    }))
    self:AddField(NumericField({
        name = "size",
        value = 100,
        minValue = 10,
        maxValue = 5000,
        title = "Size:",
        tooltip = "Size of the paint brush",
        decimals = 0,
    }))

    self:AddField(NumericField({
        name = "spread",
        title = "Spread:",
        tooltip = "Spread",
        value = 100,
        minValue = 1,
        maxValue = 500,
        step = 1,
        decimals = 0,
    }))
    self:AddField(NumericField({
        name = "noise",
        title = "Noise:",
        tooltip = "noise",
        value = 100,
        minValue = 1,
        maxValue = 2000,
        step = 1,
        decimals = 0,
    }))

    local children = {
        self.btnSet,
        self.btnBrush,
        self.objectDefPanel:GetControl(),
        btnClose,
    }
    for i = 1, #self.filters do
        table.insert(children, self.filters[i])
    end

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
    self:SetInvisibleFields("size", "spread", "noise", "amount")
    self.type = "brush"
end

function ObjectDefsView:IsValidTest(state)
    return state:is_A(AddObjectState) or state:is_A(BrushObjectState)
end

function ObjectDefsView:OnFieldChange(name, value)
    if name == "team" then
        self.objectDefPanel:SelectTeamID(value, type(value))
    end
end

function ObjectDefsView:OnLeaveState(state)
    for _, btn in pairs({self.btnBrush, self.btnSet}) do
        btn:SetPressedState(false)
    end
end

function ObjectDefsView:OnEnterState(state)
    if state:is_A(AddObjectState) then
        self.btnSet:SetPressedState(true)
    elseif state:is_A(BrushObjectState) then
        self.btnBrush:SetPressedState(true)
    end
end

UnitDefsView = ObjectDefsView:extends{}
function UnitDefsView:MakePanel(tbl)
    self.objectDefPanel = UnitDefsPanel(tbl)
end
function UnitDefsView:EnterState()
    if self.type == "set" then
        self:SetInvisibleFields("size", "noise", "spread")
        SB.stateManager:SetState(AddUnitState(self, self.objectDefPanel:GetSelectedObjectDefs()))
    elseif self.type == "brush" then
        self:SetInvisibleFields("amount")
        SB.stateManager:SetState(BrushUnitState(self, self.objectDefPanel:GetSelectedObjectDefs()))
    end
end
function UnitDefsView:MakeFilters()
    self.filters = {
        Label:New {
            x = 1,
            y = 8 + SB.conf.C_HEIGHT * 5,
            caption = "Type:",
        },
        ComboBox:New {
            height = SB.conf.B_HEIGHT,
            x = 40,
            y = 1 + SB.conf.C_HEIGHT * 5,
            items = {
                "Units", "Buildings", "All",
            },
            width = 90,
            OnSelect = {
                function (obj, itemIdx, selected)
                    if selected then
                        self.objectDefPanel:SelectUnitTypesID(itemIdx)
                    end
                end
            },
        },
        Label:New {
            caption = "Terrain:",
            x = 140,
            y = 8 + SB.conf.C_HEIGHT * 5,
        },
        ComboBox:New {
            height = SB.conf.B_HEIGHT,
            x = 190,
            y = 1 + SB.conf.C_HEIGHT * 5,
            items = {
                "Ground", "Air", "Water", "All",
            },
            width = 90,
            OnSelect = {
                function (obj, itemIdx, selected)
                    if selected then
                        self.objectDefPanel:SelectTerrainID(itemIdx)
                    end
                end
            },
        },
        Label:New {
			x = 1,
			y = 8 + SB.conf.C_HEIGHT * 7,
			caption = "Search:",
		},
		EditBox:New {
			height = SB.conf.B_HEIGHT,
			x = 60,
			y = 1 + SB.conf.C_HEIGHT * 7,
			text = "",
			width = 90,
			OnTextInput = {
                function(obj)
                    self.objectDefPanel:SetSearchString(obj.text)
                end
            },
            OnKeyPress = {
                function(obj)
                    self.objectDefPanel:SetSearchString(obj.text)
                end
            },
		},
    }
end

FeatureDefsView = ObjectDefsView:extends{}
function FeatureDefsView:MakePanel(tbl)
    self.objectDefPanel = FeatureDefsPanel(tbl)
end
function FeatureDefsView:EnterState()
    if self.type == "set" then
        self:SetInvisibleFields("size", "noise", "spread")
        SB.stateManager:SetState(AddFeatureState(self, self.objectDefPanel:GetSelectedObjectDefs()))
    elseif self.type == "brush" then
        self:SetInvisibleFields("amount")
        SB.stateManager:SetState(BrushFeatureState(self, self.objectDefPanel:GetSelectedObjectDefs()))
    end
end
function FeatureDefsView:MakeFilters()
    self.filters = {
        Label:New {
			x = 1,
			y = 8 + SB.conf.C_HEIGHT * 5,
			caption = "Type:",
		},
		ComboBox:New {
			height = SB.conf.B_HEIGHT,
			x = 40,
			y = 1 + SB.conf.C_HEIGHT * 5,
			items = {
				"Other", "Wreckage", "All",
			},
			width = 90,
			OnSelect = {
				function (obj, itemIdx, selected)
					if selected then
						self.objectDefPanel:SelectFeatureTypesID(itemIdx)
					end
				end
			},
		},
		Label:New {
			x = 140,
			y = 8 + SB.conf.C_HEIGHT * 5,
			caption = "Wreck:",
		},
		ComboBox:New {
			height = SB.conf.B_HEIGHT,
			x = 190,
			y = 1 + SB.conf.C_HEIGHT * 5,
			items = {
				"Units", "Buildings", "All",
			},
			width = 90,
			OnSelect = {
				function (obj, itemIdx, selected)
					if selected then
                        self.objectDefPanel:SelectUnitTypesID(itemIdx)
					end
				end
			},
		},
		Label:New {
			caption = "Terrain:",
			x = 290,
			y = 8 + SB.conf.C_HEIGHT * 5,
		},
		ComboBox:New {
			y = 1 + SB.conf.C_HEIGHT * 5,
			height = SB.conf.B_HEIGHT,
			items = {
				"Ground", "Air", "Water", "All",
			},
			x = 340,
			width = 90,
			OnSelect = {
				function (obj, itemIdx, selected)
					if selected then
						self.objectDefPanel:SelectTerrainID(itemIdx)
					end
				end
			},
		},
        Label:New {
			x = 1,
			y = 8 + SB.conf.C_HEIGHT * 7,
			caption = "Search:",
		},
		EditBox:New {
			height = SB.conf.B_HEIGHT,
			x = 60,
			y = 1 + SB.conf.C_HEIGHT * 7,
			text = "",
			width = 90,
			OnTextInput = {
                function(obj)
                    self.objectDefPanel:SetSearchString(obj.text)
                end
            },
            OnKeyPress = {
                function(obj)
                    self.objectDefPanel:SetSearchString(obj.text)
                end
            },
		},
    }
end
