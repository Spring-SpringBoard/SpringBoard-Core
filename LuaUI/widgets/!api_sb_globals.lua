function widget:GetInfo()
    return {
        name      = "sb_globals",
        author    = "gajop",
        license   = "MIT",
        layer     = -9999999999,
        enabled   = true,
        api       = true,
        hidden    = true,
    }
end

WG.SB_LIBS_DIR = "libs_sb/"
WG.SB = {}

-- everything breaks unless this is also included (at least an .Echo), wtf?
function widget:Initialize()
    Spring.Echo("SpringBoard libs dir: " .. tostring(WG.SB_LIBS_DIR))
end
