----------------------------------------------------------------------------
----------------------------------------------------------------------------
-- Copy this file to both the luaui/widgets and the luarules/gadgets folders

-- Set this line to the Spring Kernel installation folder
KERNEL_FOLDER = "libs/kernel/"

-- Do NOT modify the following lines
if Script.GetName() == "LuaUI" or Script.GetName() == "LuaMenu" then
	VFS.Include(KERNEL_FOLDER .. "luaui/widgets/api_spring_kernel.lua", nil, VFS.DEF_MODE)
elseif Script.GetName() == "LuaRules" then
	VFS.Include(KERNEL_FOLDER .. "luarules/gadgets/api_spring_kernel.lua", nil, VFS.DEF_MODE)
end
