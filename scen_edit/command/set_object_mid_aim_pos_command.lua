SetObjectMidAimPosCommand = UndoableCommand:extends{}
SetObjectMidAimPosCommand.className = "SetObjectMidAimPosCommand"

function SetObjectMidAimPosCommand:execute(bridge)
    local objectID = bridge.getSpringObjectID(self.objectModelID)
    local _, _, _, mpx, mpy, mpz, apx, apy, apz = bridge.spGetObjectPosition(objectID, true, true)
    self.old = {
        mpx = mpx, mpy = mpy, mpz = mpz,
        apx = apx, apy = apy, apz = apz,
    }
    bridge.spSetObjectMidAndAimPos(objectID,
        self.params.mpx, self.params.mpy, self.params.mpz,
        self.params.apx, self.params.apy, self.params.apz, true)
end

function SetObjectMidAimPosCommand:unexecute(bridge)
    local objectID = bridge.getSpringObjectID(self.objectModelID)
    bridge.spSetObjectMidAndAimPos(objectID,
        self.old.mpx, self.old.mpy, self.old.mpz,
        self.old.apx, self.old.apy, self.old.apz)
end

SetUnitMidAimPosCommand = SetObjectMidAimPosCommand:extends{}
SetUnitMidAimPosCommand.className = "SetUnitMidAimPosCommand"
function SetUnitMidAimPosCommand:init(objectModelID, params)
    self.className        = "SetUnitMidAimPosCommand"
    self.objectModelID    = objectModelID
    self.params           = params
end
function SetUnitMidAimPosCommand:execute()
    self:super("execute", unitBridge)
end
function SetUnitMidAimPosCommand:unexecute()
    self:super("unexecute", unitBridge)
end

SetFeatureMidAimPosCommand = SetObjectMidAimPosCommand:extends{}
SetFeatureMidAimPosCommand.className = "SetFeatureMidAimPosCommand"
function SetFeatureMidAimPosCommand:init(objectModelID, params)
    self.className      = "SetFeatureMidAimPosCommand"
    self.objectModelID  = objectModelID
    self.params         = params
end
function SetFeatureMidAimPosCommand:execute()
    self:super("execute", featureBridge)
end
function SetFeatureMidAimPosCommand:unexecute()
    self:super("unexecute", featureBridge)
end