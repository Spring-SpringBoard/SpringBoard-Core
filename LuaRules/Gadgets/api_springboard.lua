--------------------------
function gadget:GetInfo()
  return {
    name      = "SpringBoard: gadget",
    desc      = "Game-independent editor (gadget)",
    author    = "gajop",
    date      = "in the future",
    license   = "GPL-v2",
    layer     = 0,
    enabled   = true,
  }
end

VFS.Include("scen_edit/gadget.lua", nil, VFS.DEF_MODE)
