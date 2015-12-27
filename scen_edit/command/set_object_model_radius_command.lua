SetObjectModelRadiusCommand = UndoableCommand:extends{}
SetObjectModelRadiusCommand.className = "SetObjectModelRadiusCommand"

function SetObjectModelRadiusCommand:execute(bridge)
    local objectID = bridge.getSpringObjectID(self.objectModelID)
    self.oldHeight = bridge.spGetObjectHeight(objectID)
    self.oldRadius = bridge.spGetObjectRadius(objectID)
    bridge.spSetObjectRadiusAndHeight(objectID, self.radius, self.height)
end

function SetObjectModelRadiusCommand:unexecute(bridge)
    local objectID = bridge.getSpringObjectID(self.objectModelID)
    bridge.spSetObjectRadiusAndHeight(objectID, self.oldRadius, self.oldHeight)
end

SetUnitModelRadiusCommand = SetObjectModelRadiusCommand:extends{}
SetUnitModelRadiusCommand.className = "SetUnitModelRadiusCommand"
function SetUnitModelRadiusCommand:init(objectModelID, radius, height)
    self.className        = "SetUnitModelRadiusCommand"
    self.objectModelID  = objectModelID
    self.radius         = radius
    self.height         = height
end
function SetUnitModelRadiusCommand:execute()
    self:super("execute", unitBridge)
end
function SetUnitModelRadiusCommand:unexecute()
    self:super("unexecute", unitBridge)
end

SetFeatureModelRadiusCommand = SetObjectModelRadiusCommand:extends{}
SetFeatureModelRadiusCommand.className = "SetFeatureModelRadiusCommand"
function SetFeatureModelRadiusCommand:init(objectModelID, radius, height)
    self.className      = "SetFeatureModelRadiusCommand"
    self.objectModelID  = objectModelID
    self.radius         = radius
    self.height         = height
end
function SetFeatureModelRadiusCommand:execute()
    self:super("execute", featureBridge)
end
function SetFeatureModelRadiusCommand:unexecute()
    self:super("unexecute", featureBridge)
end