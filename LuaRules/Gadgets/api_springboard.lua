--------------------------
function gadget:GetInfo()
    return {
        name      = "SpringBoard: gadget",
        desc      = "Game-independent editor (gadget)",
        author    = "gajop",
        license   = "MIT",
        layer     = 0,
        enabled   = true,
    }
end

VFS.Include("scen_edit/gadget.lua", nil, VFS.DEF_MODE)
