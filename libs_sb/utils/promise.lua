Promise = LCS.class{}
Promise.States = {
    Pending = 1,
    Fullfilled = 2,
    Rejected = 3
}

local function IsPromise(obj)
    return type(obj) == "table" and getmetatable(obj) == Promise
end

function Promise:init(f)
    self.state = Promise.States.Pending
    self.fullfillmentHandlers = {}
    self.rejectionHandlers = {}
    self.finallyHandlers = {}

    local resolveClb = function(value)
        self:resolve(value)
    end
    local rejectClb = function(reason)
        self:reject(reason)
    end

    if f ~= nil then
        local success, err = pcall(function()
            f(resolveClb, rejectClb)
        end)
        if not success then
            self:reject(err)
        end
    end
end

function Promise:resolve(value)
    if self.state ~= Promise.States.Pending then
        return
    end

    self.state = Promise.States.Fullfilled
    self.value = value

    for _, clb in ipairs(self.fullfillmentHandlers) do
        clb(value)
    end
    for _, clb in ipairs(self.finallyHandlers) do
        clb()
    end

    self.fullfillmentHandlers = {}
    self.finallyHandlers = {}
end

function Promise:reject(reason)
    if self.state ~= Promise.States.Pending then
        return
    end

    self.state = Promise.States.Rejected
    self.reason = reason

    for _, clb in ipairs(self.rejectionHandlers) do
        clb(reason)
    end
    for _, clb in ipairs(self.finallyHandlers) do
        clb()
    end

    self.rejectionHandlers = {}
    self.finallyHandlers = {}
end

function Promise:catch(clb)
    assert(clb ~= nil and type(clb) == 'function')

    local promise = Promise()

    local rejectionHandler = promise:__makeRejectionHandler(clb)

    if self.state == Promise.States.Rejected then
        rejectionHandler(self.reason)
    elseif self.state == Promise.States.Pending then
        table.insert(self.rejectionHandlers, rejectionHandler)
    end

    return promise
end

function Promise:next(clb)
    assert(clb ~= nil and type(clb) == 'function')

    local promise = Promise()
    promise.value = self.value

    local fullfillmentHandler = promise:__makeFullfillmentHandler(clb)
    local rejectionHandler = promise:__makeRejectionHandler()

    if self.state == Promise.States.Fullfilled then
        fullfillmentHandler(self.value)
    elseif self.state == Promise.States.Rejected then
        rejectionHandler(self.reason)
    else
        table.insert(self.fullfillmentHandlers, fullfillmentHandler)
        table.insert(self.rejectionHandlers, rejectionHandler)
    end

    return promise
end

-- TODO: implement :finally
-- function Promise:finally(clb)
--     assert(clb ~= nil and type(clb) == 'function')

--     if self.state == Promise.States.Pending then
--         table.insert(self.finallyHandlers, clb)
--         return self:__makeOnResolvePromise()
--     end

--     clb()
--     local promise = Promise()
--     promise:resolve(self.value)
--     return promise
-- end

function Promise:__makeFullfillmentHandler(clb)
    return function(value)
        local result
        if clb ~= nil then
            result = clb(value)
        else
            result = value
        end

        if IsPromise(result) then
            result:next(function(v) self:resolve(v) end)
            result:catch(function(r) self:reject(r) end)
        else
            self:resolve(result)
        end
    end
end

function Promise:__makeRejectionHandler(clb)
    return function(reason)
        local result
        if clb ~= nil then
            result = clb(reason)
        else
            result = reason
        end

        if IsPromise(result) then
            result:catch(function(v) self:reject(v) end)
        else
            self:reject(result)
        end
    end
end

-- Tests
local lu = luaunit
if not lu then
    return
end

-- luacheck:ignore
function testImmediateResolving()
    local promise = Promise(function(resolve, reject)
        resolve(42)
    end)
    local resolved = false
    promise:next(function(value)
        resolved = true
        lu.assertEquals(value, 42)
    end)
    lu.assertIsTrue(resolved)
end

function testResolvingWithPromise()
    local promise = Promise(function(resolve, reject)
        resolve(13)
    end):next(function(value)
        return Promise(function(resolve)
            resolve(value * 2)
        end)
    end)
    lu.assertEquals(promise.state, Promise.States.Fullfilled)
    lu.assertEquals(promise.value, 26)
end

function testImmediateRejecting()
    local promise = Promise(function(resolve, reject)
        reject(12)
    end)
    local rejected = false
    promise:catch(function(reason)
        rejected = true
        lu.assertEquals(reason, 12)
    end)
    lu.assertIsTrue(rejected)
end

function testPromiseChainingResolveWithValues()
    local finalValue
    Promise(function(resolve)
        resolve(5)
    end):next(function(value)
        return value * 2
    end):next(function(value)
        return value * 2
    end):next(function(value)
        finalValue = value
    end)
    lu.assertEquals(finalValue, 20)
end

function testPromiseChainingRejectWithValues()
    local finalReason
    Promise(function(resolve, reject)
        reject("reason13")
    end):next(function(value)
        lu.fail("Shouldn't be in a :next when rejected")
        return value * 2
    end):next(function(value)
        lu.fail("Shouldn't be in a :next when rejected")
        return value * 2
    end):next(function(value)
        lu.fail("Shouldn't be in a :next when rejected")
        return value * 2
    end):catch(function(reason)
        finalReason = reason
    end)
    lu.assertEquals(finalReason, "reason13")
end

function testPromiseChainingResolveWithPromises()
    local finalValue
    Promise(function(resolve)
        resolve(7)
    end):next(function(value)
        return Promise(function(resolve)
            resolve(value * 2)
        end)
    end):next(function(value)
        return Promise(function(resolve)
            resolve(value * 2)
        end)
    end):next(function(value)
        finalValue = value
    end)
    lu.assertEquals(finalValue, 28)
end

function testPromiseChainingRejectWithPromises()
    local finalReason
    Promise(function(resolve, reject)
        reject(257)
    end):next(function(value)
        lu.fail("Shouldn't be in a :next when rejected")
        return Promise(function(resolve)
            resolve(value * 2)
        end)
    end):next(function(value)
        lu.fail("Shouldn't be in a :next when rejected")
        return Promise(function(resolve)
            resolve(value * 2)
        end)
    end):catch(function(reason)
        finalReason = reason
    end)
    lu.assertEquals(finalReason, 257)
end

function testPromiseChainingWithPromisesAndResolve()
    local finalValue
    local p1, p2, p3

    p1 = Promise()

    p1:next(function(value)
        p2 = Promise()
        return p2
    end):next(function(value)
        p3 = Promise()
        return p3
    end):next(function(value)
        finalValue = value
    end)

    lu.assertNotIsNil(p1)
    lu.assertEquals(p1.state, Promise.States.Pending)
    p1:resolve(3)
    lu.assertEquals(p1.state, Promise.States.Fullfilled)

    lu.assertNotIsNil(p2)
    lu.assertEquals(p2.state, Promise.States.Pending)
    p2:resolve(6)
    lu.assertEquals(p2.state, Promise.States.Fullfilled)

    lu.assertNotIsNil(p3)
    lu.assertEquals(p3.state, Promise.States.Pending)
    p3:resolve(12)
    lu.assertEquals(p3.state, Promise.States.Fullfilled)

    lu.assertEquals(finalValue, 12)
end

function testPromiseChainingWithPromisesAndCatch()
    local finalValue
    local p1, p2, p3
    local failedReason

    p1 = Promise()

    p1:next(function(value)
        p2 = Promise()
        return p2
    end):next(function(value)
        p3 = Promise()
        return p3
    end):catch(function(reason)
        failedReason = reason
    end)

    lu.assertNotIsNil(p1)
    lu.assertEquals(p1.state, Promise.States.Pending)
    p1:resolve(3)
    lu.assertEquals(p1.state, Promise.States.Fullfilled)

    lu.assertNotIsNil(p2)
    lu.assertEquals(p2.state, Promise.States.Pending)
    p2:resolve(6)
    lu.assertEquals(p2.state, Promise.States.Fullfilled)

    lu.assertNotIsNil(p3)
    lu.assertEquals(p3.state, Promise.States.Pending)
    p3:reject("failure:42")
    lu.assertEquals(failedReason, "failure:42")
    lu.assertEquals(p3.state, Promise.States.Rejected)
end

if lu then
    lu.LuaUnit.run()
end
