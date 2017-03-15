function widget:GetInfo()
  return {
    name      = "SpringBoard_widget",
    desc      = "Game-independent editor (widget)",
    author    = "gajop",
    date      = "in the future",
    license   = "GPL-v2",
    layer     = 1001,
    enabled   = true,
  }
end

VFS.Include("scen_edit/widget.lua", nil, VFS.DEF_MODE)
