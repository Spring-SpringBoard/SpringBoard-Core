BrushManagers = LCS.class{}

function BrushManagers:init()
    self.brushNameMapping = {}
end

function BrushManagers:GetBrushManager(brushName)
    if not self.brushNameMapping[brushName] then
        self.brushNameMapping[brushName] = BrushManager()
    end
    return self.brushNameMapping[brushName]
end

function BrushManagers:GetBrushManagers()
    return self.brushNameMapping
end


BrushManager = Observable:extends{}

function BrushManager:init()
    self:super('init')

    self:Clear()
end

function BrushManager:Clear()
    if self.brushes then
        for brushID, _ in pairs(self.brushes) do
            self:RemoveBrush(brushID)
        end
    end

    self.__brushIDCounter = 0
    self.brushes = {}
    self.brushOrder = {}
end

function BrushManager:AddBrush(brush)
    self.__brushIDCounter = self.__brushIDCounter + 1
    brush.brushID = self.__brushIDCounter
    self.brushes[brush.brushID] = brush
    table.insert(self.brushOrder, brush.brushID)

    self:callListeners("OnBrushAdded", brush)

    return brush.brushID
end

function BrushManager:RemoveBrush(removeBrushID)
    local brush = self.brushes[removeBrushID]
    self.brushes[removeBrushID] = nil
    for i, brushID in pairs(self.brushOrder) do
        if removeBrushID == brushID then
            table.remove(self.brushOrder, i)
            break
        end
    end

    self:callListeners("OnBrushRemoved", brush)
end

function BrushManager:UpdateBrush(brushID, key, value)
    local brush = self.brushes[brushID]
    brush.opts[key] = value

    self:callListeners("OnBrushUpdated", brush, key, value)
end

function BrushManager:UpdateBrushImage(brushID, image)
    local brush = self.brushes[brushID]
    brush.image = image

    self:callListeners("OnBrushImageUpdated", brush, image)
end

function BrushManager:GetBrush(brushID)
    return self.brushes[brushID]
end

function BrushManager:GetBrushIDs()
    return self.brushOrder
end

function BrushManager:GetBrushes()
    return self.brushes
end

function BrushManager:Serialize()
    local brushes = {}
    for _, brush in pairs(self.brushes) do
        local brushCopy = Table.DeepCopy(brush)
        brushCopy.image = nil
        brushes[brush.brushID] = brushCopy
    end
    return {
        brushes = brushes,
        order = self.brushOrder,
    }
end

function BrushManager:Load(data)
    self:Clear()

    for _, brushID in pairs(data.order) do
        local brushData = data.brushes[brushID]
        self:AddBrush(brushData)
    end
end


------------------------------------------------
-- Listener definition
------------------------------------------------
BrushManagerListener = LCS.class.abstract{}

function BrushManagerListener:OnBrushAdded(brush)
end

function BrushManagerListener:OnBrushRemoved(brush)
end

function BrushManagerListener:OnBrushUpdated(brush, key, value)
end

function BrushManagerListener:OnBrushImageUpdated(brush, image)
end
------------------------------------------------
-- End listener definition
------------------------------------------------
