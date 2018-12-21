_FeatureS11N = _ObjectS11N:extends{}

-- local modelIDs = {}
function _FeatureS11N:OnInit()
    self.funcs = {
        pos = {
            get = function(objectID)
                local px, py, pz = Spring.GetFeaturePosition(objectID)
                return {x = px, y = py, z = pz}
            end,
            set = function(objectID, value)
                Spring.SetFeaturePosition(objectID, value.x, value.y, value.z)
            end,
            humanName = "Position",
        },
        vel = {
            get = function(objectID)
                local vx, vy, vz = Spring.GetFeatureVelocity(objectID)
                return {x = vx, y = vy, z = vz}
            end,
            set = function(objectID, value)
                Spring.SetFeatureVelocity(objectID, value.x, value.y, value.z)
            end,
            humanName = "Velocity",
        },
        mass = {
            get = function(objectID)
                return Spring.GetFeatureMass(objectID)
            end,
            set = function(objectID, value)
                Spring.SetFeatureMass(objectID, value)
            end,
            minValue = 1,
            humanName = "Mass",
        },
        dir = {
            get = function(objectID)
                local dirX, dirY, dirZ = Spring.GetFeatureDirection(objectID)
                return {x = dirX, y = dirY, z = dirZ}
            end,
            set = function(objectID, value)
                Spring.SetFeatureDirection(objectID, value.x, value.y, value.z)
            end,
            humanName = "Direction",
        },
        rot = {
            get = function(objectID)
                local x, y, z = Spring.GetFeatureRotation(objectID)
                return {x = x, y = y, z = z}
            end,
            set = function(objectID, value)
                Spring.SetFeatureRotation(objectID, value.x, value.y, value.z)
            end,
            humanName = "Rotation",
        },
        midAimPos = {
            get = function(objectID)
                local px, py, pz, mpx, mpy, mpz, apx, apy, apz = Spring.GetFeaturePosition(objectID, true, true)
                return {mid = {x = mpx - px, y = mpy - py, z = mpz - pz},
                        aim = {x = apx - px, y = apy - py, z = apz - pz}}
            end,
            set = function(objectID, value)
                Spring.SetFeatureMidAndAimPos(objectID,
                    value.mid.x, value.mid.y, value.mid.z,
                    value.aim.x, value.aim.y, value.aim.z, true)
            end,
        },
        blocking = {
            get =function(objectID)
                local isBlocking, isSolidObjectCollidable, isProjectileCollidable,
                  isRaySegmentCollidable, crushable, blockEnemyPushing, blockHeightChanges = Spring.GetFeatureBlocking(objectID)
                return { isBlocking = isBlocking, isSolidObjectCollidable = isSolidObjectCollidable, isProjectileCollidable = isProjectileCollidable,
                  isRaySegmentCollidable = isRaySegmentCollidable, crushable = crushable, blockEnemyPushing = blockEnemyPushing, blockHeightChanges = blockHeightChanges }
            end,
            set = function(objectID, value)
                Spring.SetFeatureBlocking(objectID, value.isBlocking, value.isSolidObjectCollidable, value.isProjectileCollidable, value.isRaySegmentCollidable, value.crushable, value.blockEnemyPushing, value.blockHeightChanges)
            end,
        },
        radiusHeight = {
            get = function(objectID)
                return { height = Spring.GetFeatureHeight(objectID),
                         radius = Spring.GetFeatureRadius(objectID) }
            end,
            set = function(objectID, value)
                Spring.SetFeatureRadiusAndHeight(objectID, value.radius, value.height)
            end,
        },
        collision = {
            get = function(objectID)
                local scaleX, scaleY, scaleZ,
                      offsetX, offsetY, offsetZ,
                      vType, testType, axis, disabled = Spring.GetFeatureCollisionVolumeData(objectID)
                return {
                    scaleX = scaleX, scaleY = scaleY, scaleZ = scaleZ,
                    offsetX = offsetX, offsetY = offsetY, offsetZ = offsetZ,
                    vType = vType, testType = testType, axis = axis, disabled = disabled,
                }
            end,
            set = function(objectID, value)
                Spring.SetFeatureCollisionVolumeData(objectID,
                    value.scaleX, value.scaleY, value.scaleZ,
                    value.offsetX, value.offsetY, value.offsetZ,
                    value.vType, 1, value.axis)
            end,
        },
        team = {
            get = function(objectID)
                return Spring.GetFeatureTeam(objectID)
            end,
        },
        defName = {
            get = function(objectID)
                return FeatureDefs[Spring.GetFeatureDefID(objectID)].name
            end,
        },
        health = {
            get = function(objectID)
                return Spring.GetFeatureHealth(objectID)
            end,
            set = function(objectID, value)
                Spring.SetFeatureHealth(objectID, value)
            end,
            minValue = 1,
        },
        rules = {
            get = function(objectID)
                return Spring.GetFeatureRulesParams(objectID)
            end,
            set = function(objectID, value)
                for ruleName, ruleValue in pairs(value) do
                    if ruleValue == false then
                        Spring.SetFeatureRulesParam(objectID, ruleName, nil)
                    else
                        Spring.SetFeatureRulesParam(objectID, ruleName, ruleValue)
                    end
                end
            end,
        },
        resources = {
            get = function(objectID)
                local metal, metalMax, energy, energyMax, reclaimLeft, reclaimTime = Spring.GetFeatureResources(objectID)
                if reclaimTime ~= nil then
                    return {
                        metal = metal,
                        metalMax = metalMax,
                        energy = energy,
                        energyMax = energyMax,
                        reclaimTime = reclaimTime,
                        reclaimLeft = reclaimLeft
                    }
                else
                    return {
                        metal = metal,
                        energy = energy
                    }
                end
            end,
            set = function(objectID, value)
                if value.reclaimLeft then
                    Spring.SetFeatureResources(objectID, value.metal, value.energy,
                        value.reclaimTime, value.reclaimLeft,value.metalMax, value.energyMax)
                else
                    Spring.SetFeatureResources(objectID, value.metal, value.energy)
                end
            end
        }
        -- modelID = {
        --     get = function(objectID)
        --         return modelIDs[objectID]
        --     end,
        --     set = function(objectID, value)
        --         Spring.Echo("S11N", objectID, value)
        --         modelIDs[objectID] = value
        --     end,
        -- }
    }
    self:__AddModelIDField()
end

-- FIXME: objectID argument not used
-- luacheck: ignore 412
function _FeatureS11N:CreateObject(object, objectID)
    local y = Spring.GetGroundHeight(object.pos.x, object.pos.z)
    local objectID = Spring.CreateFeature(object.defName, object.pos.x, object.pos.y, object.pos.z)
    if y ~= object.pos.y then
        Spring.SetFeatureMoveCtrl(objectID, true)
        -- Spring.SetFeatureMoveCtrl(objectID, false)
    end
    return objectID
end

function _FeatureS11N:DestroyObject(objectID)
    return Spring.DestroyFeature(objectID, false, true)
end

function _FeatureS11N:GetAllObjectIDs()
    return Spring.GetAllFeatures()
end
