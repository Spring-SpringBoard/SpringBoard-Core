SB.Include(Path.Join(SB_VIEW_DIR, "editor_view.lua"))

AnimationsView = EditorView:extends{}

function AnimationsView:init()
    self:super("init")

    local tvPieceControl = TreeView:New {
        nodes = nodes,
    }
    self:AddControl("pos-sep", {
        Label:New {
            caption = "Position",
        },
        Line:New {
            x = 50,
            width = self.VALUE_POS,
        }
    })
    self:AddField(GroupField({
        NumericField({
            name = "posX",
            title = "X:",
            tooltip = "Position (x)",
            value = 1,
            minValue = 0,
            maxValue = Game.mapSizeX,
            step = 1,
            width = 100,
            decimals = 0,
        }),
        NumericField({
            name = "posY",
            title = "Y:",
            tooltip = "Position (y)",
            value = 0,
            step = 1,
            width = 100,
            decimals = 0,
        }),
        NumericField({
            name = "posZ",
            title = "Z:",
            tooltip = "Position (z)",
            value = 1,
            minValue = 0,
            maxValue = Game.mapSizeZ,
            step = 1,
            width = 100,
            decimals = 0,
        }),
    }))

    self:AddControl("angle-sep", {
        Label:New {
            caption = "Angle",
        },
        Line:New {
            x = 50,
            width = self.VALUE_POS,
        }
    })
    self:AddField(GroupField({
        NumericField({
            name = "angleX",
            title = "X:",
            tooltip = "X angle",
            value = 0,
            step = 0.2,
            width = 100,
        }),
        NumericField({
            name = "angleY",
            title = "Y:",
            tooltip = "Y angle",
            value = 0,
            step = 0.2,
            width = 100,
        }),
        NumericField({
            name = "angleZ",
            title = "Z:",
            tooltip = "Z angle",
            value = 0,
            step = 0.2,
            width = 100,
        }),
    }))

    local children = { tvPieceControl }
    table.insert(children,
        ScrollPanel:New {
            x = 0,
            y = "0%",
            bottom = 30,
            right = 0,
            borderColor = {0,0,0,0},
            horizontalScrollbar = false,
            children = { self.stackPanel },
        }
    )

    self:Finalize(children)
    SB.view.selectionManager:addListener(self)
    self:OnSelectionChanged(SB.view.selectionManager:GetSelection())
    SB.commandManager:addListener(self)
end

function AnimationsView:GetPieceHierarchy(objectID, bridge)
    local pieceInfo = Spring.GetUnitPieceInfo(objectID, 1)
    local pieceName = pieceInfo.name
    Spring.Log(pieceInfo, pieceName)
end

function AnimationsView:OnSelectionChanged(selection)
    self.selectionChanging = true
    local objectID, bridge
    if #selection.units > 0 then
        objectID = selection.units[1]
        bridge = unitBridge
    end
    if objectID then
        self:GetPieceHierarchy(objectID, unitBridge)
    end
    self.selectionChanging = false
end

function AnimationsView:OnCommandExecuted()
    if not self._startedChanging then
        self:OnSelectionChanged(SB.view.selectionManager:GetSelection())
    end
end

function AnimationsView:OnStartChange(name)
    SB.commandManager:execute(SetMultipleCommandModeCommand(true))
end

function AnimationsView:OnEndChange(name)
    SB.commandManager:execute(SetMultipleCommandModeCommand(false))
end

function AnimationsView:OnFieldChange(name, value)
    if not self.selectionChanging then

        local commands = {}
        local selection = SB.view.selectionManager:GetSelection()
        for _, objectID in pairs(selection.units) do
            local modelID = SB.model.unitManager:getModelUnitID(objectID)
            table.insert(commands, SetUnitParamCommand(modelID, name, value))
        end
        local compoundCommand = CompoundCommand(commands)
        SB.commandManager:execute(compoundCommand)
    end
end
