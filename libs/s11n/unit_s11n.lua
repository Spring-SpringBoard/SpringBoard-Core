_UnitS11N = _ObjectS11N:extends{}

local function boolToNumber(bool)
    if bool then
        return 1
    else
        return 0
    end
end

local function isUnitCommand(command)
    local luaState = WG or GG
    if not luaState.SB then
        return
    end
    local SB = luaState.SB

    if command.params ~= nil and #command.params ~= 1 then
        return false
    end
    local unitCommands = { "DEATHWAIT", "ATTACK", "GUARD", "REPAIR", "LOAD_UNITS", "UNLOAD_UNITS", "RECLAIM", "RESSURECT", "CAPTURE", "LOOPBACKATTACK" }
    for _, unitCommand in pairs(unitCommands) do
        if command.name == unitCommand then
            return true
        end
    end
    return false
end

function _UnitS11N:OnInit()
    self.funcs = {
        pos = {
            get = function(objectID)
                local px, py, pz = Spring.GetUnitPosition(objectID)
                return {x = px, y = py, z = pz}
            end,
            set = function(objectID, value)
                Spring.SetUnitPosition(objectID, value.x, value.y, value.z)
            end,
            humanName = "Position",
        },
        vel = {
            get = function(objectID)
                local vx, vy, vz = Spring.GetUnitVelocity(objectID)
                return {x = vx, y = vy, z = vz}
            end,
            set = function(objectID, value)
                Spring.SetUnitVelocity(objectID, value.x, value.y, value.z)
            end,
            humanName = "Velocity",
        },
        mass = {
            get = function(objectID)
                return Spring.GetUnitMass(objectID)
            end,
            set = function(objectID, value)
                Spring.SetUnitMass(objectID, value)
            end,
            humanName = "Mass",
        },
        dir = {
            get = function(objectID)
                local dirX, dirY, dirZ = Spring.GetUnitDirection(objectID)
                return {x = dirX, y = dirY, z = dirZ}
            end,
            set = function(objectID, value)
                Spring.SetUnitDirection(objectID, value.x, value.y, value.z)
            end,
            humanName = "Direction",
        },
        rot = {
            get = function(objectID)
                local x, y, z = Spring.GetUnitRotation(objectID)
                return {x = x, y = y, z = z}
            end,
            set = function(objectID, value)
                Spring.SetUnitRotation(objectID, value.x, value.y, value.z)
            end,
            humanName = "Rotation",
        },
        midAimPos = {
            get = function(objectID)
                local px, py, pz, mpx, mpy, mpz, apx, apy, apz = Spring.GetUnitPosition(objectID, true, true)
                return {mid = {x = mpx - px, y = mpy - py, z = mpz - pz},
                        aim = {x = apx - px, y = apy - py, z = apz - pz}}
            end,
            set = function(objectID, value)
                Spring.SetUnitMidAndAimPos(objectID,
                    value.mid.x, value.mid.y, value.mid.z,
                    value.aim.x, value.aim.y, value.aim.z, true)
            end,
        },
        maxRange = {
            get = function(objectID)
                return Spring.GetUnitMaxRange(objectID)
            end,
            set = function(objectID, value)
                Spring.SetUnitMaxRange(objectID, value)
            end,
        },
        blocking = {
            get = function(objectID)
                local isBlocking, isSolidObjectCollidable, isProjectileCollidable,
                  isRaySegmentCollidable, crushable, blockEnemyPushing, blockHeightChanges = Spring.GetUnitBlocking(objectID)
                return { isBlocking = isBlocking, isSolidObjectCollidable =
                  isSolidObjectCollidable, isProjectileCollidable = isProjectileCollidable,
                  isRaySegmentCollidable = isRaySegmentCollidable, crushable = crushable, blockEnemyPushing = blockEnemyPushing, blockHeightChanges = blockHeightChanges}
            end,
            set = function(objectID, value)
                Spring.SetUnitBlocking(objectID, value.isBlocking, value.isSolidObjectCollidable, value.isProjectileCollidable, value.isRaySegmentCollidable, value.crushable, value.blockEnemyPushing, value.blockHeightChanges)
            end,
        },
        radiusHeight = {
            get = function(objectID)
                return { height = Spring.GetUnitHeight(objectID),
                         radius = Spring.GetUnitRadius(objectID) }
            end,
            set = function(objectID, value)
                Spring.SetUnitRadiusAndHeight(objectID, value.radius, value.height)
            end,
        },
        collision = {
            get = function(objectID)
                local scaleX, scaleY, scaleZ,
                      offsetX, offsetY, offsetZ,
                      vType, testType, axis, disabled = Spring.GetUnitCollisionVolumeData(objectID)
                return {
                    scaleX = scaleX, scaleY = scaleY, scaleZ = scaleZ,
                    offsetX = offsetX, offsetY = offsetY, offsetZ = offsetZ,
                    vType = vType, testType = testType, axis = axis, disabled = disabled,
                }
            end,
            set = function(objectID, value)
                Spring.SetUnitCollisionVolumeData(objectID,
                    value.scaleX, value.scaleY, value.scaleZ,
                    value.offsetX, value.offsetY, value.offsetZ,
                    value.vType, 1, value.axis)
            end,
        },
        team = {
            get = function(objectID)
                return Spring.GetUnitTeam(objectID)
            end,
            set = function(objectID, value)
                if Spring.GetUnitTeam(objectID) ~= value then
                    Spring.TransferUnit(objectID, value, false)
                end
            end,
        },
        defName = {
            get = function(objectID)
                return UnitDefs[Spring.GetUnitDefID(objectID)].name
            end,
        },
        health = {
            get = function(objectID)
                return Spring.GetUnitHealth(objectID)
            end,
            set = function(objectID, value)
                Spring.SetUnitHealth(objectID, value)
            end,
            minValue = 1,
        },
        paralyze = {
            get = function(objectID)
                local _, _, paralyze = Spring.GetUnitHealth(objectID)
                return paralyze
            end,
            set =  function(objectID, value)
                Spring.SetUnitHealth(objectID, {paralyze=value})
            end,
        },
        capture = {
            get = function(objectID)
                local _, _, _, capture = Spring.GetUnitHealth(objectID)
                return capture
            end,
            set = function(objectID, value)
                Spring.SetUnitHealth(objectID, {capture=value})
            end,
        },
        build = {
            get = function(objectID)
                local _, _, _, _, build = Spring.GetUnitHealth(objectID)
                return build
            end,
            set = function(objectID, value)
                Spring.SetUnitHealth(objectID, {build=value})
            end,
        },
        maxHealth = {
            get = function(objectID)
                local _, maxHealth = Spring.GetUnitHealth(objectID)
                return maxHealth
            end,
            set = function(objectID, value)
                Spring.SetUnitMaxHealth(objectID, value)
            end,
        },
        tooltip = {
            get = function(objectID)
                return Spring.GetUnitTooltip(objectID)
            end,
            set = function(objectID, value)
                Spring.SetUnitTooltip(objectID, value)
            end,
        },
        stockpile = {
            get = function(objectID)
                return Spring.GetUnitStockpile(objectID)
            end,
            set = function(objectID, value)
                Spring.SetUnitStockpile(objectID, value)
            end,
        },
        experience = {
            get = function(objectID)
                return Spring.GetUnitExperience(objectID)
            end,
            set = function(objectID, value)
                Spring.SetUnitExperience(objectID, value)
            end,
        },
        neutral = {
            get = function(objectID)
                return Spring.GetUnitNeutral(objectID)
            end,
            set = function(objectID, value)
                Spring.SetUnitNeutral(objectID, value)
            end,
        },
        fuel = {
            get = function(objectID)
                return Spring.GetUnitFuel(objectID)
            end,
            set = function(objectID, value)
                Spring.SetUnitFuel(objectID, value)
            end,
        },
        states = {
            get = function(objectID)
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
            set = function(objectID, value)
                if value.fireState ~= nil then
                    Spring.GiveOrderToUnit(objectID, CMD.FIRE_STATE, {value.fireState}, {})
                end
                if value.moveState ~= nil then
                    Spring.GiveOrderToUnit(objectID, CMD.MOVE_STATE, {value.moveState}, {})
                end
                if value.active ~= nil then
                    Spring.GiveOrderToUnit(objectID, CMD.ONOFF, {boolToNumber(value.active)}, {})
                end
                if value["repeat"] ~= nil then
                    Spring.GiveOrderToUnit(objectID, CMD.REPEAT, {boolToNumber(value["repeat"])}, {})
                end
                if value.cloak ~= nil then
                    Spring.GiveOrderToUnit(objectID, CMD.CLOAK, {boolToNumber(value.cloak)}, {})
                end
                if value.trajectory ~= nil then
                    Spring.GiveOrderToUnit(objectID, CMD.TRAJECTORY, {boolToNumber(value.trajectory)}, {})
                end
                -- FIXME: needs to be done differently as it clears the commands
                -- if value.autoRepairLevel ~= nil then
                --     Spring.GiveOrderToUnit(objectID, CMD.AUTOREPAIRLEVEL, {boolToNumber(value.autoRepairLevel)}, {})
                -- end
                if value.loopbackAttack ~= nil then
                    Spring.GiveOrderToUnit(objectID, CMD.LOOPBACKATTACK, {boolToNumber(value.loopbackAttack)}, {})
                end
            end,
        },
-- Erorrs are thrown in some cases (widget)
--         losState = function(objectID)
--             local s = {}
--             for _, allyTeamID in pairs(Spring.GetAllyTeamList()) do
--                 Spring.Echo(objectID, allyTeamID)
--                 s[allyTeamID] = Spring.GetUnitLosState(objectID, allyTeamID)
--             end
--             return s
--         end,
--         losState = function(objectID, value)
--             for allyTeamID, v in pairs(value) do
--                 Spring.SetUnitLosState(objectID, allyTeamID, v)
--             end
--         end,
        rules = {
            get = function(objectID)
                return Spring.GetUnitRulesParams(objectID)
            end,
            set = function(objectID, value)
                for ruleName, ruleValue in pairs(value) do
                    if ruleValue == false then
                        Spring.SetUnitRulesParam(objectID, ruleName, nil)
                    else
                        Spring.SetUnitRulesParam(objectID, ruleName, ruleValue)
                    end
                end
            end,
        },
        commands = {
            get = function(objectID)
                -- -1 needed here to work an Engine limit (otherwise we get errors)
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
                        if command.name ~= nil then
                            command.id = nil
                        end
                        -- serialized unit commands use the model unit id
                        if isUnitCommand(command) then
                            command.params[1] = self:GetModelID(command.params[1])
                        end
                    end
                end
                return commands
            end,
            set = function(objectID, value)
                for _, command in pairs(value) do
                    local params
                    -- unit commands need to get the real unit ID
                    if isUnitCommand(command) then
                        params = { self:GetSpringID(command.params[1]) }
                    else
                        params = command.params
                    end
                    if command.name ~= "BUILD_COMMAND" then
                        local cmdID = CMD[command.name] or command.id
                        Spring.GiveOrderToUnit(objectID, cmdID, params, {"shift"})
                    else
                        Spring.GiveOrderToUnit(objectID, -UnitDefNames[command.buildUnitDef].id, params, {"shift"})
                    end
                end
                local commands = Spring.GetUnitCommands(objectID, -1)
            end,
        },
        harvestStorage = {
            get = function(objectID)
                return Spring.GetUnitHarvestStorage(objectID)
            end,
            set = function(objectID, value)
                Spring.SetUnitHarvestStorage(objectID, value)
            end,
        },
        resources = {
            get = function(objectID)
                local metalMake, metalUse, energyMake, energyUse = Spring.GetUnitResources(objectID)
                return { metalMake=metalMake, metalUse=metalUse, energyMake=energyMake, energyUse=energyUse }
            end,
            set = function(objectID, value)
                Spring.SetUnitResourcing(objectID, {
                    umm = value.metalMake,
                    umu = value.metalUse,
                    uem = value.energyMake,
                    ueu = value.energyUse
                })
            end,
        },
        armored = {
            get = function(objectID)
                local armored, armorMultiple = Spring.GetUnitArmored(objectID)
                return { armored = armored, armorMultiple = armorMultiple }
            end,
            set = function(objectID, value)
                Spring.SetUnitArmored(objectID, value.armored, value.armorMultiple)
            end,
        },
        movectrl = {
            get = function(objectID)
                -- FIXME: IsEnabled doesn't exist?!
                if not Spring.MoveCtrl.IsEnabled then
                    return false
                end
                return Spring.MoveCtrl.IsEnabled(objectID)
            end,
            set = function(objectID, value)
                if value then
                    Spring.MoveCtrl.Enable(objectID)
                else
                    Spring.MoveCtrl.Disable(objectID)
                end
            end,
        },
        crashing = {
            get = function(objectID)
                local moveData = Spring.GetUnitMoveTypeData(objectID)
                if moveData and (moveData.name == "airplane" or moveData.name == "gunship") then
                    return moveData.aircraftState == "crashing"
                end
                return nil
            end,
            set = function(objectID, value)
                Spring.SetUnitCrashing(objectID, value)
            end,
        },
        gravity = {
            set = function(objectID, value)
                Spring.MoveCtrl.SetGravity(objectID, value)
            end,
        },
    }

    -- FIXME: movectrl get is not available in unsynced
    if not Spring.MoveCtrl then
        self.funcs.movectrl.get = nil
    end
    -- TODO: this isn't available
    -- unit.alwaysVisible = Spring.GetAlwaysVisible(unitID)
    self:__AddModelIDField()
end

function _UnitS11N:CreateObject(object, objectID)
    objectID = nil
    local objectID = Spring.CreateUnit(object.defName, object.pos.x, object.pos.y, object.pos.z, 0, object.team, false, true, objectID)
    return objectID
end

function _UnitS11N:DestroyObject(objectID)
    return Spring.DestroyUnit(objectID, false, true)
end

function _UnitS11N:GetAllObjectIDs()
    return Spring.GetAllUnits()
end
