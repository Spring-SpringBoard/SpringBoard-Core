AddObjectCommand = AbstractCommand:extends{}
AddObjectCommand.className = "AddObjectCommand"

function AddObjectCommand:execute(bridge)
    local objectID = bridge.s11n:Add(self.params)
    if self.objectModelID == nil then
        self.objectModelID = bridge.getObjectModelID(objectID)
    else
        bridge.setObjectModelID(objectID, self.objectModelID)
    end
end

function AddObjectCommand:unexecute(bridge)
    if self.objectModelID then
        local objectID = bridge.getObjectSpringID(self.objectModelID)
        bridge.spDestroyObject(objectID, false, true)
    end
end

AddUnitCommand = AddObjectCommand:extends{}
AddUnitCommand.className = "AddUnitCommand"
function AddUnitCommand:init(params)
    self.className        = "AddUnitCommand"
    self.params           = params
end
function AddUnitCommand:execute()
    self:super("execute", unitBridge)
end
function AddUnitCommand:unexecute()
    self:super("unexecute", unitBridge)
end

AddFeatureCommand = AddObjectCommand:extends{}
AddFeatureCommand.className = "AddFeatureCommand"
function AddFeatureCommand:init(params)
    self.className        = "AddFeatureCommand"
    self.params           = params
end
function AddFeatureCommand:execute()
    self:super("execute", featureBridge)
end
function AddFeatureCommand:unexecute()
    self:super("unexecute", featureBridge)
end