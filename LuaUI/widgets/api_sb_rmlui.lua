function widget:GetInfo()
    return {
        name      = "SpringBoard RmlUi Framework",
        desc      = "RmlUi UI framework integration for SpringBoard",
        author    = "SpringBoard Team",
        date      = "2025",
        license   = "GPL",
        layer     = -999, -- Draw before other widgets
        enabled   = true
    }
end

-- RmlUi integration for SpringBoard
-- This widget provides RmlUi rendering and input handling

local rmlui
local initialized = false

function widget:Initialize()
    -- Check if RmlUi is available
    if not Spring.RmlUi then
        Spring.Log("SpringBoard RmlUi", LOG.WARNING, "RmlUi not available in this Spring engine version")
        Spring.Log("SpringBoard RmlUi", LOG.WARNING, "Falling back to Chili UI (engine needs BAR 105.1.1+ for RmlUi)")
        widgetHandler:RemoveWidget(self)
        return false
    end

    rmlui = Spring.RmlUi
    initialized = true

    Spring.Log("SpringBoard RmlUi", LOG.NOTICE, "RmlUi Framework initialized")
    return true
end

function widget:Shutdown()
    initialized = false
end

function widget:ViewResize(vsx, vsy)
    if not initialized then
        return
    end

    -- Update RmlUi context dimensions
    if SB and SB.rmlui then
        SB.rmlui:UpdateDimensions()
    end
end

function widget:DrawScreen()
    if not initialized then
        return
    end

    -- Render RmlUi context
    if SB and SB.rmlui then
        SB.rmlui:Render()
    end
end

function widget:MouseMove(x, y, dx, dy, button)
    if not initialized then
        return false
    end

    if SB and SB.rmlui then
        return SB.rmlui:MouseMove(x, y, dx, dy)
    end

    return false
end

function widget:MousePress(x, y, button)
    if not initialized then
        return false
    end

    if SB and SB.rmlui then
        return SB.rmlui:MouseButton(x, y, button, true)
    end

    return false
end

function widget:MouseRelease(x, y, button)
    if not initialized then
        return false
    end

    if SB and SB.rmlui then
        return SB.rmlui:MouseButton(x, y, button, false)
    end

    return false
end

function widget:MouseWheel(up, value)
    if not initialized then
        return false
    end

    -- RmlUi mouse wheel handling would go here
    -- Implementation depends on RmlUi API availability

    return false
end

function widget:KeyPress(key, mods, isRepeat, label, unicode)
    if not initialized then
        return false
    end

    if SB and SB.rmlui then
        local handled = SB.rmlui:KeyEvent(key, true, mods)
        if handled then
            return true
        end

        -- Handle text input
        if unicode and unicode > 0 then
            return SB.rmlui:TextInput(unicode)
        end
    end

    return false
end

function widget:KeyRelease(key, mods, label, unicode)
    if not initialized then
        return false
    end

    if SB and SB.rmlui then
        return SB.rmlui:KeyEvent(key, false, mods)
    end

    return false
end

-- Expose RmlUi to other widgets
function widget:GetRmlUi()
    return rmlui
end
