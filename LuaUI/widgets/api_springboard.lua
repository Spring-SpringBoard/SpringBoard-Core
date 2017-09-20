local info = {
  name      = "SpringBoard_widget",
  desc      = "Game-independent editor (widget)",
  author    = "gajop",
  date      = "in the future",
  license   = "GPL-v2",
  layer     = 1001,
  enabled   = true,
  -- handler   = true,
}

-- new addonhandler currently disabled
if addon and addon.InGetInfo and false then
    widget = addon
    return info
else
    function widget:GetInfo()
        return info
    end
end

VFS.Include("scen_edit/widget.lua", nil, VFS.DEF_MODE)
