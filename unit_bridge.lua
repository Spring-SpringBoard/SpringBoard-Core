_UnitBridge = _ObjectBridge:extends{}

function _UnitBridge:init()
    _ObjectBridge.init(self)
    self.getFuncs = {
        pos = function(objectID)
            local px, py, pz = Spring.GetUnitPosition(objectID)
            return {x = px, y = py, z = pz}
        end,
        vel = function(objectID)
            local vx, vy, vz = Spring.GetUnitVelocity(objectID)
            return {x = vx, y = vy, z = vz}
        end,
        mass = function(objectID)
            return Spring.GetUnitMass(objectID)
        end,
        dir = function(objectID)
            local dirX, dirY, dirZ = Spring.GetUnitDirection(objectID)
            return {x = dirX, y = dirY, z = dirZ}
        end,
        rot = function(objectID)
            local x, y, z = Spring.GetUnitRotation(objectID)
            return {x = x, y = y, z = z}
        end,
        midAimPos = function(objectID)
            local px, py, pz, mpx, mpy, mpz, apx, apy, apz = Spring.GetUnitPosition(objectID, true, true)
            return {mid = {x = mpx - px, y = mpy - py, z = mpz - pz},
                    aim = {x = apx - px, y = apy - py, z = apz - pz}}
        end,
        maxRange = function(objectID)
            return Spring.GetUnitMaxRange(objectID)
        end,
        blocking = function(objectID)
            local isBlocking, isSolidObjectCollidable, isProjectileCollidable,
              isRaySegmentCollidable, crushable, blockEnemyPushing, blockHeightChanges = Spring.GetUnitBlocking(objectID)
            return { isBlocking = isBlocking, isSolidObjectCollidable = isSolidObjectCollidable, isProjectileCollidable = isProjectileCollidable,
              isRaySegmentCollidable = isRaySegmentCollidable, crushable = crushable, blockEnemyPushing = blockEnemyPushing, blockHeightChanges = blockHeightChanges }
        end,
        radiusHeight = function(objectID)
            return { height = Spring.GetUnitHeight(objectID),
                     radius = Spring.GetUnitRadius(objectID) }
        end,
        collision = function(objectID)
            local scaleX, scaleY, scaleZ,
                  offsetX, offsetY, offsetZ,
                  vType, testType, axis, disabled = Spring.GetUnitCollisionVolumeData(objectID)
            return {
                scaleX = scaleX, scaleY = scaleY, scaleZ = scaleZ,
                offsetX = offsetX, offsetY = offsetY, offsetZ = offsetZ,
                vType = vType, testType = testType, axis = axis, disabled = disabled,
            }
        end,
        team = function(objectID)
            return Spring.GetUnitTeam(objectID)
        end,
        defName = function(objectID)
            return UnitDefs[Spring.GetUnitDefID(objectID)].name
        end,
        health = function(objectID)
            return Spring.GetUnitHealth(objectID)
        end,
        paralyze = function(objectID)
            local _, _, paralyze = Spring.GetUnitHealth(objectID)
            return paralyze
        end,
        capture = function(objectID)
            local _, _, _, capture = Spring.GetUnitHealth(objectID)
            return capture
        end,
        build = function(objectID)
            local _, _, _, _, build = Spring.GetUnitHealth(objectID)
            return build
        end,
        maxHealth = function(objectID)
            local _, maxHealth = Spring.GetUnitHealth(objectID)
            return maxHealth
        end,
        tooltip = function(objectID)
            return Spring.GetUnitTooltip(objectID)
        end,
        stockpile = function(objectID)
            return Spring.GetUnitStockpile(objectID)
        end,
        experience = function(objectID)
            return Spring.GetUnitExperience(objectID)
        end,
        neutral = function(objectID)
            return Spring.GetUnitNeutral(objectID)
        end,
        fuel = function(objectID)
            return Spring.GetUnitFuel(objectID)
        end,
        states = function(objectID)
            local states = Spring.GetUnitStates(objectID)
            if states then
                states = {
                    fireState       = states.firestate,
                    moveState       = states.movestate,
                    ["repeat"]      = states["repeat"],
                    cloak           = states.cloak,
                    active          = states.active,
                    trajectory      = states.trajectory,
                    autoLand        = states.autoland,
                    autoRepairLevel = states.autorepairlevel,
                    loopbackAttack  = states.loopbackattack,
                }
            end
            return states
        end,
        losState = function(objectID)
            return Spring.GetUnitLosState(objectID, 0)
        end,
        rules = function(objectID)
            local ret = {}
            for _, foo in pairs(Spring.GetUnitRulesParams(objectID)) do
                if type(foo) == "table" then
                    for rule, value in pairs(foo) do
                        ret[rule] = value
                    end
                end
            end
            return ret
        end,
        commands = function(objectID)
            -- -1 needed here to work around jk's attempt at optimization (otherwise we get errors)
            local commands = Spring.GetUnitCommands(objectID, -1)
            if commands then
                for _, command in pairs(commands) do
                    if command.id >= 0 then
                        command.name = CMD[command.id]
                    else
                        command.name = "BUILD_COMMAND"
                        local buildUnitDef = UnitDefs[math.abs(command.id)]
                        if buildUnitDef ~= nil then
                            command.buildUnitDef = buildUnitDef.name
                        else
                            Spring.Log("s11n", LOG.ERROR, "No such unit def: (" .. math.abs(command.id) ..  ") for build command: " .. tostring(command.id))
                        end
                    end
                    command.options = nil
                    command.tag = nil
                    command.id = nil
                    -- TODO
                    -- serialized unit commands use the model unit id
    --                 if isUnitCommand(command) then
    --                     command.params[1] = self:getModelUnitId(command.params[1])
    --                 end
                end
            end
            return commands
        end,
        harvestStorage = function(objectID)
            return Spring.GetUnitHarvestStorage(objectID)
        end,
        resources = function(objectID)
            local metalMake, metalUse, energyMake, energyUse = Spring.GetUnitResources(objectID)
            return { metalMake=metalMake, metalUse=metalUse, energyMake=energyMake, energyUse=energyUse }
        end,
        armored = function(objectID)
            local armored, armorMultiple = Spring.GetUnitArmored(objectID)
            return { armored = armored, armorMultiple = armorMultiple }
        end,
        crashing = function(objectID)
            local moveData = Spring.GetUnitMoveTypeData(objectID)
            if moveData and (moveData.name == "airplane" or moveData.name == "gunship") then
                return moveData.aircraftState == "crashing"
            end
            return nil
        end,
    }
    self.setFuncs = {
        pos = function(objectID, value)
            Spring.SetUnitPosition(objectID, value.x, value.y, value.z)
        end,
        vel = function(objectID, value)
            Spring.SetUnitVelocity(objectID, value.x, value.y, value.z)
        end,
        mass = function(objectID, value)
            Spring.SetUnitMass(objectID, value)
        end,
        dir = function(objectID, value)
            Spring.SetUnitDirection(objectID, value.x, value.y, value.z)
        end,
        rot = function(objectID, value)
            Spring.SetUnitRotation(objectID, value.x, value.y, value.z)
        end,
        midAimPos = function(objectID, value)
            Spring.SetUnitMidAndAimPos(objectID, value.mid.x, value.mid.y, value.mid.z,
                                                 value.aim.x, value.aim.y, value.aim.z, true)
        end,
        maxRange = function(objectID, value)
            Spring.SetUnitMaxRange(objectID, value)
        end,
        blocking = function(objectID, value)
            Spring.SetUnitBlocking(objectID, value.isBlocking, value.isSolidObjectCollidable, value.isProjectileCollidable, value.isRaySegmentCollidable, value.crushable, value.blockEnemyPushing, value.blockHeightChanges)
        end,
        radiusHeight = function(objectID, value)
            Spring.SetUnitRadiusAndHeight(objectID, value.radius, value.height)
        end,
        collision = function(objectID, value)
            Spring.SetUnitCollisionVolumeData(objectID,
                value.scaleX, value.scaleY, value.scaleZ,
                value.offsetX, value.offsetY, value.offsetZ,
                value.vType, 1, value.axis)
        end,
        team = function(objectID, value)
            if Spring.GetUnitTeam(objectID) ~= value then
                Spring.TransferUnit(objectID, value, false)
            end
        end,
        health = function(objectID, value)
            Spring.SetUnitHealth(objectID, value)
        end,
        capture = function(objectID, value)
            Spring.SetUnitHealth(objectID, {capture=value})
        end,
        paralyze = function(objectID, value)
            Spring.SetUnitHealth(objectID, {paralyze=value})
        end,
        build = function(objectID, value)
            Spring.SetUnitHealth(objectID, {build=value})
        end,
        maxHealth = function(objectID, value)
            Spring.SetUnitMaxHealth(objectID, value)
        end,
        tooltip = function(objectID, value)
            Spring.SetUnitTooltip(objectID, value)
        end,
        stockpile = function(objectID, value)
            Spring.SetUnitStockpile(objectID, value)
        end,
        experience = function(objectID, value)
            Spring.SetUnitExperience(objectID, value)
        end,
        neutral = function(objectID, value)
            Spring.SetUnitNeutral(objectID, value)
        end,
        fuel = function(objectID, value)
            Spring.SetUnitFuel(objectID, value)
        end,
        states = function(objectID, value)
            if value.fireState ~= nil then
                Spring.GiveOrderToUnit(objectID, CMD.INSERT,
                    { 0, CMD.FIRE_STATE, 0, value.fireState},
                    {"alt"}
                )
            end
            if value.moveState ~= nil then
                Spring.GiveOrderToUnit(objectID, CMD.INSERT,
                    { 0, CMD.MOVE_STATE, 0, value.moveState},
                    {"alt"}
                )
            end
            if value.active ~= nil then
                Spring.GiveOrderToUnit(objectID, CMD.INSERT,
                    { 0, CMD.ONOFF, 0, boolToNumber(value.active)},
                    {"alt"}
                )
            end
            if value["repeat"] ~= nil then
                Spring.GiveOrderToUnit(objectID, CMD.INSERT,
                    { 0, CMD.REPEAT, 0, boolToNumber(value["repeat"])},
                    {"alt"}
                )
            end
            if value.cloak ~= nil then
                Spring.GiveOrderToUnit(objectID, CMD.INSERT,
                    { 0, CMD.CLOAK, 0, boolToNumber(value.cloak)},
                    {"alt"}
                )
            end
            if value.trajectory ~= nil then
                 Spring.GiveOrderToUnit(objectID, CMD.INSERT,
                    { 0, CMD.TRAJECTORY, 0, boolToNumber(value.trajectory)},
                    {"alt"}
                )
            end
            if value.autoRepairLevel ~= nil then
                 Spring.GiveOrderToUnit(objectID, CMD.INSERT,
                    { 0, CMD.AUTOREPAIRLEVEL, 0, boolToNumber(value.autoRepairLevel)},
                    {"alt"}
                )
            end
            if value.loopbackAttack ~= nil then
                 Spring.GiveOrderToUnit(objectID, CMD.INSERT,
                    { 0, CMD.LOOPBACKATTACK, 0, boolToNumber(value.loopbackAttack)},
                    {"alt"}
                )
            end
        end,
        losState = function(objectID, value)
            Spring.SetUnitLosState(objectID, 0, value)
        end,
        rules = function(objectID, value)
            for ruleName, ruleValue in pairs(value) do
                Spring.SetUnitRulesParam(objectID, ruleName, ruleValue)
            end
        end,
        commands = function(objectID, value)
            for _, command in pairs(value) do
                if command.name ~= "BUILD_COMMAND" then
                    Spring.GiveOrderToUnit(objectID, CMD[command.name], command.params, {"shift"})
                else
                    Spring.GiveOrderToUnit(objectID, -UnitDefNames[command.buildUnitDef].id, command.params, {"shift"})
                end
            end
        end,
        armored = function(objectID, value)
            Spring.SetUnitArmored(objectID, value.armored, value.armorMultiple)
        end,
        harvestStorage = function(objectID, value)
            Spring.SetUnitHarvestStorage(objectID, value)
        end,
        resources = function(objectID, value)
            Spring.SetUnitResourcing(objectID, {
                umm = value.metalMake,
                umu = value.metalUse,
                uem = value.energyMake,
                ueu = value.energyUse
            })
        end,
        gravity = function(objectID, value)
            Spring.MoveCtrl.SetGravity(objectID, value)
        end,
        movectrl = function(objectID, value)
            if value then
                Spring.MoveCtrl.Enable(objectID)
            else
                Spring.MoveCtrl.Disable(objectID)
            end
        end,
        crashing = function(objectID, value)
            Spring.SetUnitCrashing(objectID, value)
        end,
    }
end

function _UnitBridge:CreateObject(object)
    local objectID = Spring.CreateUnit(object.defName, object.pos.x, object.pos.y, object.pos.z, 0, object.team, false, true)
    return objectID
end
