AbstractMapEditingState = AbstractEditingState:extends{}

function AbstractMapEditingState:init(editorView)
	AbstractEditingState.init(self, editorView)
    -- common fields
    self.size                = self.editorView.fields["size"].value
    if self.editorView.fields["rotation"] then
        self.rotation        = self.editorView.fields["rotation"].value
    end
end

function AbstractMapEditingState:KeyPress(key, mods, isRepeat, label, unicode)
    -- disable keybindings while changing stuff
    if self.startedChanging then
        return false
    end
    -- FIXME: cannot use "super" here in the current version of LCS and the new version is broken
    if AbstractEditingState.KeyPress(self, key, mods, isRepeat, label, unicode) then
        return true
    end
	
	return false
--     if key == 27 then -- KEYSYMS.ESC
--         SCEN_EDIT.stateManager:SetState(DefaultState())
--     else
--         return false
--     end
--     return true
end

function AbstractMapEditingState:CanApply()
	local now = os.clock()
    if not self.lastTime then
        self.lastTime = now
        return true
    end
    local delay = math.max(self.applyDelay or 0, self._initialDelay or 0)
    if delay ~= 0 then
        if now - self.lastTime >= delay then
            self.lastTime = now
            self._initialDelay = 0
            return true
        else
            return false
        end
    end
    return true
end

function AbstractMapEditingState:_Apply(...)
    if self:CanApply() then
		self:Apply(...)
	end
end

function AbstractMapEditingState:MousePress(x, y, button)
    if button == 1 or button == 3 then
        local result, coords = Spring.TraceScreenRay(x, y, true)
        if result == "ground"  then
            self:startChanging()
            self.x, self.z = coords[1], coords[3]
            self:_Apply(self:GetApplyParams(self.x, self.z, button))
            return true
        end
    end
end

function AbstractMapEditingState:MouseRelease(x, y, button)
    if button == 1 or button == 3 then
        self:stopChanging()
    end
end

function AbstractMapEditingState:MouseMove(x, y, dx, dy, button)
    local result, coords = Spring.TraceScreenRay(x, y, true)
    if result == "ground"  then
        self.x, self.z = coords[1], coords[3]
        self:_Apply(self:GetApplyParams(self.x, self.z, button))
    end
    return true
end

function AbstractMapEditingState:MouseWheel(up, value)
    local alt, _, _, shift = Spring.GetModKeyState()
    if shift then
        if up then
            self.size = self.size + self.size * 0.2 + 2
        else
            self.size = self.size - self.size * 0.2 - 2
        end
        self.editorView:Set("size", self.size)
        return true
    elseif alt and self.rotation ~= nil then
        if up then
            self.rotation = self.rotation + 5
        else
            self.rotation = self.rotation - 5
        end
        -- may uncomment this to rotate around
        -- self.rotation = self.rotation - math.floor(self.rotation/360) * 360
        self.editorView:Set("rotation", self.rotation)
        return true
    end
end

function AbstractMapEditingState:Update()
    if not self.startedChanging then
        return
    end
    if self.updateDelay then
        local now = os.clock()
        if not self.lastUpdateTime or now - self.lastUpdateTime >= self.updateDelay then
            self.lastUpdateTime = now
        else
            return false
        end
    end
    local x, y, button1, _, button3 = Spring.GetMouseState()
    local _, _, _, shift = Spring.GetModKeyState()
    if button1 or button3 then
        local result, coords = Spring.TraceScreenRay(x, y, true)
        if result == "ground" then
            local x, z = coords[1], coords[3]
            local tolerance = 200
            if math.abs(x - self.x) > tolerance or math.abs(z - self.z) > tolerance then
                self.x, self.z = x, z
            end
			local button
			if button1 then
				button = 1
			elseif button3 then
				button = 3
			end
            self:_Apply(self:GetApplyParams(self.x, self.z, button))
        end
    end
end

function AbstractMapEditingState:startChanging()
    if not self.startedChanging then
        self._initialDelay = self.initialDelay
        local cmd = SetMultipleCommandModeCommand(true)
        SCEN_EDIT.commandManager:execute(cmd)
        self.startedChanging = true
    end
end

function AbstractMapEditingState:stopChanging()
    if self.startedChanging then
        local cmd = SetMultipleCommandModeCommand(false)
        SCEN_EDIT.commandManager:execute(cmd)
        self.startedChanging = false
        self.lastTime = nil
    end
end

-- To implement custom states, override the following methods

function AbstractMapEditingState:GetApplyParams(x, z, button)
	return x, z
end

function AbstractMapEditingState:Apply(...)
end