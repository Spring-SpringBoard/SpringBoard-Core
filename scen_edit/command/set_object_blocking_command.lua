SetObjectBlockingCommand = UndoableCommand:extends{}
SetObjectBlockingCommand.className = "SetObjectBlockingCommand"

function SetObjectBlockingCommand:execute(bridge)
    local objectID = bridge.getSpringObjectID(self.objectModelID)
    local isBlocking, isSolidObjectCollidable, isProjectileCollidable,
              isRaySegmentCollidable, crushable, blockEnemyPushing, blockHeightChanges = bridge.spGetObjectBlocking(objectID)
    self.old = {
        isBlocking = isBlocking, isSolidObjectCollidable = isSolidObjectCollidable, isProjectileCollidable = isProjectileCollidable, isRaySegmentCollidable = isRaySegmentCollidable, crushable = crushable, blockEnemyPushing = blockEnemyPushing, blockHeightChanges = blockHeightChanges
    }
    bridge.spSetObjectBlocking(objectID,
        self.params.isBlocking, self.params.isSolidObjectCollidable, self.params.isProjectileCollidable, self.params.isRaySegmentCollidable, self.params.crushable, self.params.blockEnemyPushing, self.params.blockHeightChanges)
end

function SetObjectBlockingCommand:unexecute(bridge)
    local objectID = bridge.getSpringObjectID(self.objectModelID)
    bridge.spSetObjectBlocking(objectID,
        self.old.isBlocking, self.old.isSolidObjectCollidable, self.old.isProjectileCollidable, self.old.isRaySegmentCollidable, self.old.crushable, self.old.blockEnemyPushing, self.old.blockHeightChanges)
end

SetUnitBlockingCommand = SetObjectBlockingCommand:extends{}
SetUnitBlockingCommand.className = "SetUnitBlockingCommand"
function SetUnitBlockingCommand:init(objectModelID, params)
    self.className        = "SetUnitBlockingCommand"
    self.objectModelID    = objectModelID
    self.params           = params
end
function SetUnitBlockingCommand:execute()
    self:super("execute", unitBridge)
end
function SetUnitBlockingCommand:unexecute()
    self:super("unexecute", unitBridge)
end

SetFeatureBlockingCommand = SetObjectBlockingCommand:extends{}
SetFeatureBlockingCommand.className = "SetFeatureBlockingCommand"
function SetFeatureBlockingCommand:init(objectModelID, params)
    self.className      = "SetFeatureBlockingCommand"
    self.objectModelID  = objectModelID
    self.params         = params
end
function SetFeatureBlockingCommand:execute()
    self:super("execute", featureBridge)
end
function SetFeatureBlockingCommand:unexecute()
    self:super("unexecute", featureBridge)
end