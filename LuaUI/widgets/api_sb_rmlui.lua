function widget:GetInfo()
    return {
        name      = "SpringBoard RmlUi Framework",
        desc      = "RmlUi UI framework integration for SpringBoard",
        author    = "SpringBoard Team",
        date      = "2025",
        license   = "GPL",
        layer     = 9999, -- Draw on top of other widgets (including debug console at layer 5000)
        enabled   = true
    }
end

-- RmlUi integration for SpringBoard
-- This widget provides RmlUi rendering and input handling

local rmlui
local initialized = false

function widget:Initialize()
    if Spring.GetGameRulesParam("useRml") ~= "true" then
        widgetHandler:RemoveWidget(self)
        return
    end
    -- Check if RmlUi is available
    if not RmlUi then
        Spring.Log("SpringBoard RmlUi", LOG.WARNING, "RmlUi not available in this Spring engine version")
        Spring.Log("SpringBoard RmlUi", LOG.WARNING, "Falling back to Chili UI (engine needs BAR 105.1.1+ for RmlUi)")
        widgetHandler:RemoveWidget(self)
        return false
    end

    rmlui = RmlUi
    initialized = true

    Spring.Log("SpringBoard RmlUi", LOG.NOTICE, "RmlUi Framework initialized")
    return true
end

function widget:Shutdown()
    initialized = false
end

function widget:DrawScreen()
    if not initialized then
        return
    end

    -- Render RmlUi context
    if WG.SB and WG.SB.rmlui then
        WG.SB.rmlui:Render()
    end
end

function widget:MouseMove(x, y, dx, dy, button)
    if not initialized then
        return false
    end

    if WG.SB and WG.SB.rmlui then
        return WG.SB.rmlui:MouseMove(x, y, dx, dy)
    end

    return false
end

function widget:MousePress(x, y, button)
    if not initialized then
        return false
    end

    if WG.SB and WG.SB.rmlui then
        return WG.SB.rmlui:MouseButton(x, y, button, true)
    end

    return false
end

function widget:MouseRelease(x, y, button)
    if not initialized then
        return false
    end

    if WG.SB and WG.SB.rmlui then
        return WG.SB.rmlui:MouseButton(x, y, button, false)
    end

    return false
end

function widget:KeyPress(key, mods, isRepeat, label, unicode)
    if not initialized then
        return false
    end

    if WG.SB and WG.SB.rmlui then
        -- Only send key event to RmlUi for special keys (navigation, backspace, etc.)
        -- Don't handle printable characters here - let TextInput handle those
        if not unicode or unicode == 0 then
            local handled = WG.SB.rmlui:KeyEvent(key, true, mods)
            return handled
        end
    end

    return false
end

function widget:KeyRelease(key, mods, label, unicode)
    if not initialized then
        return false
    end

    if WG.SB and WG.SB.rmlui then
        return WG.SB.rmlui:KeyEvent(key, false, mods)
    end

    return false
end

-- TextInput is not needed here - the engine handles it at C++ level
-- and Chili widget returns false when in RmlUi mode

-- Expose RmlUi to other widgets
function widget:GetRmlUi()
    return rmlui
end
