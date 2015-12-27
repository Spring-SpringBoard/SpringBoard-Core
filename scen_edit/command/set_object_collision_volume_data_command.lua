SetObjectCollisionVolumeDataCommand = UndoableCommand:extends{}
SetObjectCollisionVolumeDataCommand.className = "SetObjectCollisionVolumeDataCommand"

function SetObjectCollisionVolumeDataCommand:execute(bridge)
    local objectID = bridge.getSpringObjectID(self.objectModelID)
    local scaleX, scaleY, scaleZ,
          offsetX, offsetY, offsetZ,
          vType, testType, axis, disabled = bridge.spGetObjectCollisionVolumeData(objectID)
    self.old = {
        scaleX = scaleX, scaleY = scaleY, scaleZ = scaleZ,
        offsetX = offsetX, offsetY = offsetY, offsetZ = offsetZ,
        vType = vType, testType = testType, axis = axis, disabled = disabled,
    }
    bridge.spSetObjectCollisionVolumeData(objectID,
        self.params.scaleX, self.params.scaleY, self.params.scaleZ,
        self.params.offsetX, self.params.offsetY, self.params.offsetZ,
        self.params.vType, 1, self.params.axis)
end

function SetObjectCollisionVolumeDataCommand:unexecute(bridge)
    local objectID = bridge.getSpringObjectID(self.objectModelID)
    bridge.spSetObjectCollisionVolumeData(objectID,
        self.old.scaleX, self.old.scaleY, self.old.scaleZ,
        self.old.offsetX, self.old.offsetY, self.old.offsetZ,
        self.old.vType, 1, self.old.axis)
end

SetUnitCollisionVolumeDataCommand = SetObjectCollisionVolumeDataCommand:extends{}
SetUnitCollisionVolumeDataCommand.className = "SetUnitCollisionVolumeDataCommand"
function SetUnitCollisionVolumeDataCommand:init(objectModelID, params)
    self.className        = "SetUnitCollisionVolumeDataCommand"
    self.objectModelID    = objectModelID
    self.params           = params
end
function SetUnitCollisionVolumeDataCommand:execute()
    self:super("execute", unitBridge)
end
function SetUnitCollisionVolumeDataCommand:unexecute()
    self:super("unexecute", unitBridge)
end

SetFeatureCollisionVolumeDataCommand = SetObjectCollisionVolumeDataCommand:extends{}
SetFeatureCollisionVolumeDataCommand.className = "SetFeatureCollisionVolumeDataCommand"
function SetFeatureCollisionVolumeDataCommand:init(objectModelID, params)
    self.className      = "SetFeatureCollisionVolumeDataCommand"
    self.objectModelID  = objectModelID
    self.params         = params
end
function SetFeatureCollisionVolumeDataCommand:execute()
    self:super("execute", featureBridge)
end
function SetFeatureCollisionVolumeDataCommand:unexecute()
    self:super("unexecute", featureBridge)
end