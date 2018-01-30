SB.Include(Path.Join(SB_VIEW_DIR, "editor.lua"))

ObjectDefsView = Editor:extends{}

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
    self:AddDefaultKeybinding({
        self.btnBrush,
        self.btnSet,
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

    self:PopulateTeams()

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

    self.brushFields = {"size", "noise", "spread"}
    self.setFields = {"amount"}
    -- Currently we are doing random fields only for the brush mode
    -- for _, prefix in pairs({"set", "brush"}) do
    for _, prefix in pairs({"brush"}) do
        for _, axis in pairs({"x", "y", "z"}) do
            local minValue, maxValue = 0, 0
            if prefix == "brush" and axis == "y" then
                minValue, maxValue = -180, 180
            end
            local fieldMinName = prefix .. "Rot" .. axis .. "Min"
            local fieldMaxName = prefix .. "Rot" .. axis .. "Max"
            local groupField = GroupField({
                NumericField({
                    name = fieldMinName,
                    value = minValue,
                    minValue = -360,
                    maxValue = 360,
                    title = "Min rot " .. axis .. ":",
                    tooltip = "Minimum rotation " .. axis
                }),
                NumericField({
                    name = fieldMaxName,
                    value = maxValue,
                    minValue = -360,
                    maxValue = 360,
                    title = "Max rot " .. axis .. ":",
                    tooltip = "Minimum rotation " .. axis
                })
            })
            self:AddField(groupField)
            local tbl
            if prefix == "brush" then
                tbl = self.brushFields
            else
                tbl = self.setFields
            end
            table.insert(tbl, fieldMinName)
            table.insert(tbl, fieldMaxName)
            table.insert(tbl, groupField.name)
        end
    end
    self.allFields = Table.Concat(self.brushFields, self.setFields)

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
    self:SetInvisibleFields(unpack(self.allFields))
    self.type = "brush"

    SB.model.teamManager:addListener(self)
end

function ObjectDefsView:PopulateTeams()
    if self.fields["team"] then
        self:RemoveField("team")
    end

    local teamIDs = {}
    local teamCaptions = {}
    for _, team in pairs(SB.model.teamManager:getAllTeams()) do
        local teamCaption = "Team " .. team.name
        if team.color then
            teamCaption = SB.glToFontColor(team.color) .. teamCaption .. "\b"
        end
        if team.gaia then
            teamCaption = teamCaption .. " (GAIA)"
        end
        table.insert(teamCaptions, teamCaption)
        table.insert(teamIDs, team.id)
    end
    self:AddField(ChoiceField({
        name = "team",
        items = teamIDs,
        captions = teamCaptions,
        title = "Team: ",
    }))
end

function ObjectDefsView:onTeamAdded(teamID)
    self:PopulateTeams()
end

function ObjectDefsView:onTeamRemoved(teamID)
    self:PopulateTeams()
end

function ObjectDefsView:onTeamChange(teamID, team)
    self:PopulateTeams()
end

function ObjectDefsView:IsValidState(state)
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
Editor.Register({
    name = "unitDefsView",
    editor = UnitDefsView,
    tab = "Objects",
    caption = "Units",
    tooltip = "Add units",
    image = SB_IMG_DIR .. "meeple.png",
    order = 0,
})

function UnitDefsView:MakePanel(tbl)
    self.objectDefPanel = UnitDefsPanel(tbl)
end
function UnitDefsView:EnterState()
    if self.type == "set" then
        self:SetInvisibleFields(unpack(self.brushFields))
        SB.stateManager:SetState(
            AddObjectState(
                unitBridge,
                self,
                self.objectDefPanel:GetSelectedObjectDefs()
            )
        )
    elseif self.type == "brush" then
        self:SetInvisibleFields(unpack(self.setFields))
        SB.stateManager:SetState(
            BrushObjectState(
                unitBridge,
                self,
                self.objectDefPanel:GetSelectedObjectDefs()
            )
        )
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
Editor.Register({
    name = "featureDefsView",
    editor = FeatureDefsView,
    tab = "Objects",
    caption = "Features",
    tooltip = "Add features",
    image = SB_IMG_DIR .. "beech.png",
    order = 1,
})

function FeatureDefsView:MakePanel(tbl)
    self.objectDefPanel = FeatureDefsPanel(tbl)
end
function FeatureDefsView:EnterState()
    if self.type == "set" then
        self:SetInvisibleFields(unpack(self.brushFields))
        SB.stateManager:SetState(
            AddObjectState(
                featureBridge,
                self,
                self.objectDefPanel:GetSelectedObjectDefs()
            )
        )
    elseif self.type == "brush" then
        self:SetInvisibleFields(unpack(self.setFields))
        SB.stateManager:SetState(
            BrushObjectState(
                featureBridge,
                self,
                self.objectDefPanel:GetSelectedObjectDefs()
            )
        )
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
