--THIS GOES IN WIDGET FOLDER
function widget:GetInfo()
  return {
    name      = "Boxxy setup",
    desc      = "send keys presses",
    author    = "knorke, modified by Google Frog (volume type), CarRepairer (UI)",
    date      = "dec 1010",
    license   = "push button magic",
    layer     = 0,
    enabled   = false,
  }
end



local Chili
local Button
local Label
local Window
local ScrollPanel
local StackPanel
local Grid
local TextBox
local Image
local TreeView
local Trackbar
local screen0

local window_boxxy
local B_HEIGHT = 20

local echo = Spring.Echo
local scrH, scrW 		= 0,0

local euID = nil
local boxxy = nil


local function MakeButton(label, cmd, output)
	return Button:New{
		caption = label,
		--x = 10, width="25%", height=B_HEIGHT*2,
		--height='100%',width='100%',
		x=0,y=0,
		OnClick = { function(self)
			Spring.Echo ( output )
			Spring.SendLuaRulesMsg ( cmd )
		end },
	}
end

local function MakeWindow(unitID)
	local children = {}
	
	children[#children+1] = Label:New{ caption = 'Resize', }
	children[#children+1] = Label:New{ caption = '', }
	children[#children+1] = Label:New{ caption = '', }
	children[#children+1] = Label:New{ caption = '', }
	children[#children+1] = Label:New{ caption = '', }
	
	
	children[#children+1] = Label:New{ caption = 'All', }
	children[#children+1] = MakeButton( "<<", "boxxy|col|<|x", "narrower" )
	children[#children+1] = MakeButton( "<", "boxxy|col|<", "narrower" )
	children[#children+1] = MakeButton( ">", "boxxy|col|>", "wider" )
	children[#children+1] = MakeButton( ">>", "boxxy|col|>|x", "wider" )
	
	children[#children+1] = Label:New{ caption = 'X', }
	children[#children+1] = MakeButton( "<<", "boxxy|col|4|x", "narrower" )
	children[#children+1] = MakeButton( "<", "boxxy|col|4", "narrower" )
	children[#children+1] = MakeButton( ">", "boxxy|col|6", "wider" )
	children[#children+1] = MakeButton( ">>", "boxxy|col|6|x", "wider" )
	
	children[#children+1] = Label:New{ caption = 'Y', }
	children[#children+1] = MakeButton( "<<", "boxxy|col|7|x", "shorter" )
	children[#children+1] = MakeButton( "<", "boxxy|col|7", "shorter" )
	children[#children+1] = MakeButton( ">", "boxxy|col|9", "longer" )
	children[#children+1] = MakeButton( ">>", "boxxy|col|9|x", "longer" )
	
	children[#children+1] = Label:New{ caption = 'Z', }
	children[#children+1] = MakeButton( "<<", "boxxy|col|2|x", "shorter" )
	children[#children+1] = MakeButton( "<", "boxxy|col|2", "shorter" )
	children[#children+1] = MakeButton( ">", "boxxy|col|8", "taller" )
	children[#children+1] = MakeButton( ">>", "boxxy|col|8|x", "taller" )
	
	
	children[#children+1] = Label:New{ caption = 'Move', }
	children[#children+1] = Label:New{ caption = '', }
	children[#children+1] = Label:New{ caption = '', }
	children[#children+1] = Label:New{ caption = '', }
	children[#children+1] = Label:New{ caption = '', }
	
	children[#children+1] = Label:New{ caption = 'X', }
	children[#children+1] = MakeButton( "<<", "boxxy|col|A|x", "to left" )
	children[#children+1] = MakeButton( "<", "boxxy|col|A", "to left" )
	children[#children+1] = MakeButton( ">", "boxxy|col|D", "to right" )
	children[#children+1] = MakeButton( ">>", "boxxy|col|D|x", "to right" )
	
	children[#children+1] = Label:New{ caption = 'Y', }
	children[#children+1] = MakeButton( "<<", "boxxy|col|S|x", "to back" )
	children[#children+1] = MakeButton( "<", "boxxy|col|S", "to back" )
	children[#children+1] = MakeButton( ">", "boxxy|col|W", "to front" )
	children[#children+1] = MakeButton( ">>", "boxxy|col|W|x", "to front" )
	
	children[#children+1] = Label:New{ caption = 'Z', }
	children[#children+1] = MakeButton( "<<", "boxxy|col|Q|x", "to down" )
	children[#children+1] = MakeButton( "<", "boxxy|col|Q", "to down" )
	children[#children+1] = MakeButton( ">", "boxxy|col|E", "to up" )
	children[#children+1] = MakeButton( ">>", "boxxy|col|E|x", "to up" )
	
	
	children[#children+1] = Label:New{ caption = 'Volume', }
	children[#children+1] = Label:New{ caption = '', }
	children[#children+1] = Label:New{ caption = '', }
	children[#children+1] = Label:New{ caption = '', }
	children[#children+1] = Label:New{ caption = '', }
	
	children[#children+1] = MakeButton( "< Type", "boxxy|col|1", "volume type" )
	children[#children+1] = MakeButton( "Type >", "boxxy|col|3", "volume type" )
	
	children[#children+1] = MakeButton( "Vol Test", "boxxy|col|0", "toggle volume test" )
	
	children[#children+1] = Button:New{
		caption = 'ShowVol',
		x=0,y=0,
		OnClick = { function(self)
			Spring.SendCommands('debugcolvol')
		end },
	}
	
	
	--stack1 = StackPanel:New{
	stack1 = Grid:New{
		columns = 5,
		
		--autosize = false,
		resizeItems = true,
		centerItems = true,
		--bottom=B_HEIGHT,
		width = '100%',
		height= "100%",
		children = children,
	}
	
	
	scroll1 = ScrollPanel:New{
		y = B_HEIGHT,
		bottom=0,
		width = "100%",
		children = {
			stack1
		},
	}
	
	local window = Window:New{
		caption = "Box Control",
		x = scrW/3,  
		y = scrH/3,
		width='20%',
		minWidth=200,
		minHeight=300,
		parent = screen0,
		dockable = true,
		--autosize = true,
		children = {
			scroll1
		},
	}
	window_boxxy = window
end



----------------


function widget:GameFrame(frame)
	if (euID) then
		--boxxy[1]=5
		--Spring.SetUnitCollisionVolumeData  (euID, boxxy)
		boxxy[1]=math.abs ((math.sin(frame/10)*100) + 20)
		boxxy[2]=math.abs ((math.cos(frame/10)*100) + 20)
		Spring.SetUnitCollisionVolumeData  (euID, unpack(boxxy))
	end
end

function widget:SelectionChanged(selectedUnits)
	if not selectedUnits or not selectedUnits[1] then return end
	local unitID = selectedUnits[1]
	Spring.SendLuaRulesMsg ("boxxy|sel|" .. unitID )
end

function widget:Initialize()
	--[[local devMode = Spring.GetGameRulesParam('devmode') == 1
	echo ( devMode )
	if not WG.Chili or not devMode then
		widgetHandler:RemoveWidget(widget)
		return
	end]]
	
	-- setup Chili
	Chili = WG.Chili
	Button = Chili.Button
	Label = Chili.Label
	Window = Chili.Window
	ScrollPanel = Chili.ScrollPanel
	StackPanel = Chili.StackPanel
	Grid = Chili.Grid
	TextBox = Chili.TextBox
	Image = Chili.Image
	TreeView = Chili.TreeView
	Trackbar = Chili.Trackbar
	screen0 = Chili.Screen0
	
	MakeWindow()
	
end

function widget:ViewResize(vsx, vsy)
	scrW = vsx
	scrH = vsy
end

