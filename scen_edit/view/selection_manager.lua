SelectionManager = Observable:extends{}

function SelectionManager:init()
    self:super("init")

    self.selected = {}
    for name, bridge in pairs(ObjectBridge.GetObjectBridges()) do
        if not bridge.NotSelectable then
            self.selected[name] = {}
        end
    end
end

function SelectionManager:GetSelection()
    self:Update()
    return SB.deepcopy(self.selected)
end

function SelectionManager:GetSelectionCount()
    local selection = self:GetSelection()
    local selCount = 0
    for _, selected in pairs(selection) do
        selCount = selCount + #selected
    end
    return selCount
end

function SelectionManager:ClearSelection()
    self:Select({})
end

function SelectionManager:Select(selection)
    local oldSelected = self.selected
    self.selected = {}
    for name, bridge in pairs(ObjectBridge.GetObjectBridges()) do
        if not bridge.NotSelectable then
            self.selected[name] = {}
        end
    end

    for name, bridge in pairs(ObjectBridge.GetObjectBridges()) do
        if not bridge.NotSelectable then
            self.selected[name] = selection[name] or {}
            if bridge.OnSelect and not Table.Compare(oldSelected[name], self.selected[name]) then
                bridge.OnSelect(self.selected[name])
            end
        end
    end

    self:callListeners("OnSelectionChanged")
end

function SelectionManager:Update()
    if self.__disabledChange then
        return
    end

    local globalChanged = false

    for name, bridge in pairs(ObjectBridge.GetObjectBridges()) do
        if not bridge.NotSelectable then
            local objectIDs = self.selected[name]
            local changed = false

            if name == "unit" then
                local selUnits = Spring.GetSelectedUnits()
                if not Table.Compare(objectIDs, selUnits) then
                    changed = true
                end
                self.selected[name] = selUnits
            else
                if bridge.ValidObject then
                    for _, objectID in ipairs(objectIDs) do
                        if not bridge.ValidObject(objectID) then
                            changed = true
                            break
                        end
                    end
                    if changed then
                        objectIDs = {}
                        for _, objectID in ipairs(self.selected[name]) do
                            if bridge.ValidObject(objectID) then
                                table.insert(objectIDs, objectID)
                            end
                        end
                        self.selected[name] = objectIDs
                        if bridge.OnSelect then
                            bridge.OnSelect(self.selected[name])
                        end
                    end
                end
            end

            if changed then
                globalChanged = true
            end
        end
    end

    if globalChanged then
        self:callListeners("OnSelectionChanged")
    end
end

function SelectionManager:DrawWorldPreUnit()
    gl.Color(0, 1, 0, 1)
    gl.DepthTest(false)
    for name, bridge in pairs(ObjectBridge.GetObjectBridges()) do
        if not bridge.NotSelectable then
            local objectIDs = self.selected[name]
            if bridge.DrawSelected then
                for _, objectID in ipairs(objectIDs) do
                    if bridge.ValidObject == nil or bridge.ValidObject(objectID) then
                        bridge.DrawSelected(objectID)
                    end
                end
            end
        end
    end
end
