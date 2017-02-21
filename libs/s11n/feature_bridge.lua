_FeatureBridge = _ObjectBridge:extends{}

function _FeatureBridge:init()
    _ObjectBridge.init(self)
    self.getFuncs = {
        pos = function(objectID)
            local px, py, pz = Spring.GetFeaturePosition(objectID)
            return {x = px, y = py, z = pz}
        end,
        vel = function(objectID)
            local vx, vy, vz = Spring.GetFeatureVelocity(objectID)
            return {x = vx, y = vy, z = vz}
        end,
        mass = function(objectID)
            return Spring.GetFeatureMass(objectID)
        end,
        dir = function(objectID)
            local dirX, dirY, dirZ = Spring.GetFeatureDirection(objectID)
            return {x = dirX, y = dirY, z = dirZ}
        end,
        rot = function(objectID)
            local x, y, z = Spring.GetFeatureRotation(objectID)
            return {x = x, y = y, z = z}
        end,
        midAimPos = function(objectID)
            local px, py, pz, mpx, mpy, mpz, apx, apy, apz = Spring.GetFeaturePosition(objectID, true, true)
            return {mid = {x = mpx - px, y = mpy - py, z = mpz - pz},
                    aim = {x = apx - px, y = apy - py, z = apz - pz}}
        end,
        blocking = function(objectID)
            local isBlocking, isSolidObjectCollidable, isProjectileCollidable,
              isRaySegmentCollidable, crushable, blockEnemyPushing, blockHeightChanges = Spring.GetFeatureBlocking(objectID)
            return { isBlocking = isBlocking, isSolidObjectCollidable = isSolidObjectCollidable, isProjectileCollidable = isProjectileCollidable,
              isRaySegmentCollidable = isRaySegmentCollidable, crushable = crushable, blockEnemyPushing = blockEnemyPushing, blockHeightChanges = blockHeightChanges }
        end,
        radiusHeight = function(objectID)
            return { height = Spring.GetFeatureHeight(objectID),
                     radius = Spring.GetFeatureRadius(objectID) }
        end,
        collision = function(objectID)
            local scaleX, scaleY, scaleZ,
                  offsetX, offsetY, offsetZ,
                  vType, testType, axis, disabled = Spring.GetFeatureCollisionVolumeData(objectID)
            return {
                scaleX = scaleX, scaleY = scaleY, scaleZ = scaleZ,
                offsetX = offsetX, offsetY = offsetY, offsetZ = offsetZ,
                vType = vType, testType = testType, axis = axis, disabled = disabled,
            }
        end,
        team = function(objectID)
            return Spring.GetFeatureTeam(objectID)
        end,
        defName = function(objectID)
            return FeatureDefs[Spring.GetFeatureDefID(objectID)].name
        end,
        health = function(objectID)
            return Spring.GetFeatureHealth(objectID)
        end,
    }
    self.setFuncs = {
        pos = function(objectID, value)
            Spring.SetFeaturePosition(objectID, value.x, value.y, value.z)
        end,
        vel = function(objectID, value)
            Spring.SetFeatureVelocity(objectID, value.x, value.y, value.z)
        end,
        mass = function(objectID, value)
            Spring.SetFeatureMass(objectID, value)
        end,
        dir = function(objectID, value)
            Spring.SetFeatureDirection(objectID, value.x, value.y, value.z)
        end,
        rot = function(objectID, value)
            Spring.SetFeatureRotation(objectID, value.x, value.y, value.z)
        end,
        midAimPos = function(objectID, value)
            Spring.SetFeatureMidAndAimPos(objectID, value.mid.x, value.mid.y, value.mid.z,
                                                    value.aim.x, value.aim.y, value.aim.z, true)
        end,
        blocking = function(objectID, value)
            Spring.SetFeatureBlocking(objectID, value.isBlocking, value.isSolidObjectCollidable, value.isProjectileCollidable, value.isRaySegmentCollidable, value.crushable, value.blockEnemyPushing, value.blockHeightChanges)
        end,
        radiusHeight = function(objectID, value)
            Spring.SetFeatureRadiusAndHeight(objectID, value.radius, value.height)
        end,
        collision = function(objectID, value)
            Spring.SetFeatureCollisionVolumeData(objectID,
                value.scaleX, value.scaleY, value.scaleZ,
                value.offsetX, value.offsetY, value.offsetZ,
                value.vType, 1, value.axis)
        end,
        health = function(objectID, value)
            Spring.SetFeatureHealth(objectID, value)
        end,
    }
end

function _FeatureBridge:CreateObject(object)
    local objectID = Spring.CreateFeature(object.defName, object.pos.x, object.pos.y, object.pos.z)
    return objectID
end
