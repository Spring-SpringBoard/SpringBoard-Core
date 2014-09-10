AbstractState = LCS.class.abstract{}

function AbstractState:init()
end

function AbstractState:enterState()
end

function AbstractState:leaveState()
end

function AbstractState:MousePress(x, y, button)
end

function AbstractState:MouseMove(x, y, dx, dy, button)
end

function AbstractState:MouseRelease(x, y, button)
end

function AbstractState:MouseWheel(up, value)
end

function AbstractState:KeyPress(key, mods, isRepeat, label, unicode)
end

function AbstractState:GameFrame(frameNum)
end

function AbstractState:Update()
end

function AbstractState:DrawScreen()
end

function AbstractState:DrawWorld()
end

function AbstractState:DrawWorldPreUnit()
end
