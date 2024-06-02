SB.Include(Path.Join(SB.DIRS.SRC, 'view/editor.lua'))
MetalSpotEditor = Editor:extends{}
MetalSpotEditor:Register({
    name = "MetalSpotEditor",
    tab = "Misc",
    caption = "Metal-ZK",
    tooltip = "Edit metal map (ZK)",
    image = Path.Join(SB.DIRS.IMG, 'minerals.png'),
    order = 3,
})

function MetalSpotEditor:init()
    self:super("init")
    self.btnAddMetal = TabbedPanelButton({
        x = 10,
        y = 0,
        tooltip = "Add Metal Spots by clicking on the map",
        children = {
            TabbedPanelImage({ file = Path.Join(SB.DIRS.IMG, 'metal-add.png') }),
            TabbedPanelLabel({ caption = "Add" }),
        },
        OnClick = {
            function()
                self.type = "add"
                SB.stateManager:SetState(AddMetalState(self))
            end
        },
    })
    self:AddField(GroupField({
		NumericField({
            name = "defaultmetal",
            title = "Metal:",
            tooltip = "Amount of Metal in the spot",
            value = 0,
            step = .01,
            width = 100,
            decimals = 2,
        }),
        BooleanField({
            name = "defaultxmirror",
            title = "X-Mirror",
            tooltip = "Mirror X-coordinate over Z-Axis",
            width = 100,
            value = false,
        }),
        BooleanField({
            name = "defaultzmirror",         
            title = "Z-Mirror",
            tooltip = "Mirror Z-coordinate over X-Axis",
            width = 100,
            value = false,
        }),
    },
	{name = "defaultgroup"}
	))
	self:AddControl("default" .. "index", {
		Line:New {
            x = 0,
			y = 0,
            width = 480,
        },
    })
    self:AddDefaultKeybinding({
        self.btnAddMetal
    })

    local children = {
        self.btnAddMetal,
    }

    table.insert(children,
        ScrollPanel:New {
            x = 0,
            y = "8%",
            bottom = 30,
            right = 0,
            borderColor = {0,0,0,0},
            horizontalScrollbar = false,
            children = { self.stackPanel },
        }
    )
	
    local mexManagerListener = MexManagerListenerWidget(self)
    SB.model.mexManager:addListener(mexManagerListener)
    self:Finalize(children)
end

function MetalSpotEditor:__OnShow()
	SB.stateManager:SetState(ViewMetalState(self))
end

function MetalSpotEditor:AddSpot(objectID, params)
    self:AddControl("metalspot" .. objectID, {
	        Line:New {
			x = 200,
            width = self.VALUE_POS,
        },
        Label:New {
            caption = ("Metal Spot ID:" .. objectID),
        },
		Label:New {
			x = 325,
            caption = ("Mirror?"),
        },
    })
    self:AddField(GroupField({
        NumericField({
            name = "x" .. objectID,
            title = "X:",
            tooltip = "metal",
            value = params.x,
            minValue = 0,
            maxValue = Game.mapSizeX,
            step = 1,
            width = 75,
            decimals = 0,
        }),
        NumericField({
            name = "z" .. objectID,
            title = "Z:",
            tooltip = "Position (z)",
            value = params.z,
            minValue = 0,
            maxValue = Game.mapSizeZ,
            step = 1,
            width = 75,
            decimals = 0,
        }),
		NumericField({
            name = "metal" .. objectID,
            title = "Metal:",
            tooltip = "Amount of Metal in the spot",
            value = params.metal,
            step = .01,
            width = 95,
            decimals = 2,
        }),
        BooleanField({
            name = "xmirror" .. objectID,
            title = "X",
            tooltip = "Mirror X-coordinate",
            width = 60,
            value = params.xmirror,
        }),
        BooleanField({
            name = "zmirror" .. objectID,
            title = "Z",
            tooltip = "Mirror Z-coordinate",
            width = 60,
            value = params.zmirror,
        }),
		RemoveButtonField({
			name = "Remove" .. objectID,
			--title = "\255\255\1\1(X)\255\255\255\255",
			width = 50,
			tooltip = "Remove Metal Spot",
			value = false,
		}),
		    },
	{name = "group"..objectID}
	))
end

function MetalSpotEditor:RemoveSpot(objectID)
	for field, _ in pairs(self.fields) do
		local ID, _ = field:gsub('(%a+)', "")
		ID = tonumber(ID)
		if ID == objectID then
			self:RemoveField(field)
		end
	end
end

function MetalSpotEditor:OnEndChange(name)
	self:SetField(name.value)
end

function MetalSpotEditor:OnFieldChange(name, values)
	if not name:find("default") then
		if name:find("Remove") then
			local objectID, _ = name:gsub('(%a+)', "")
			SB.model.mexManager:removeMex(tonumber(objectID))
			self:RemoveSpot(tonumber(objectID))
		else
			local key, _ = name:gsub("(%d+)", "")
			local objectID, _ = name:gsub('(%a+)', "")
			objectID = tonumber(objectID)
			local partialObject = {}
			partialObject[key] = values
			SB.model.mexManager:setMex(objectID, partialObject)
		end
	end
end

function MetalSpotEditor:Populate()
	for field, _ in pairs(self.fields) do
		self:RemoveField(field)
	end
    self:AddField(GroupField({
		NumericField({
            name = "defaultmetal",
            title = "Metal:",
            tooltip = "Amount of Metal in the spot",
            value = 0,
            step = .01,
            width = 100,
            decimals = 2,
        }),
        BooleanField({
            name = "defaultxmirror",
            title = "X-Mirror",
            tooltip = "Mirror X-coordinate over Z-Axis",
            width = 100,
            value = false,
        }),
        BooleanField({
            name = "defaultzmirror",         
            title = "Z-Mirror",
            tooltip = "Mirror Z-coordinate over X-Axis",
            width = 100,
            value = false,
        }),
    },
	{name = "defaultgroup"}
	))
	self:AddControl("default" .. "index", {
		Line:New {
            x = 0,
			y = 0,
            width = 480,
        },
    })
	for ID, params in pairs(SB.model.mexManager:getAllMexes()) do
		self:AddSpot(ID, params)
	end
end

function MetalSpotEditor:IsValidState(state)
    return (state:is_A(AddMetalState))
end 

function MetalSpotEditor:OnLeaveState(state)
	if state:is_A(AddMetalState) then
		for _, btn in pairs({self.btnAddMetal}) do
			btn:SetPressedState(false)
		end
	end
end

function MetalSpotEditor:OnEnterState(state)
	if state:is_A(AddMetalState) then
		for _, btn in pairs({self.btnAddMetal}) do
			btn:SetPressedState(true)
		end
	end
end

MexManagerListenerWidget = MexManagerListener:extends{}

function MexManagerListenerWidget:init(mexEditor)
    self.ev = mexEditor
end

function MexManagerListenerWidget:onMexAdded(ID, mex)
	SB.delay(function()
    SB.delay(function()
    SB.delay(function()
	self.ev:AddSpot(ID, mex)end)end)end)
	-- local visible_spots = Spring.GetFeaturesInCylinder(mex.x, mex.z,25)
	-- if #visible_spots ~= 0 then return end
	-- local cmd = AddObjectCommand(featureBridge.name, {
		-- defName = "map_metal_spot1",
		-- pos = { x = mex.x, y = Spring.GetGroundHeight(mex.x,mex.z) , z = mex.z },
		-- dir = { x = 1, y = 0, z = 1 },
		-- team = 2,
	-- }) 
	-- SB.commandManager:execute(cmd)
end

function MexManagerListenerWidget:onMexRemoved(ID, mex)
	SB.delay(function()
    SB.delay(function()
    SB.delay(function()
    self.ev:RemoveSpot(ID)end)end)end)
	-- local visible_spots = Spring.GetFeaturesInCylinder(mex.x, mex.z,25)
	-- for _, spot in pairs(visible_spots) do
		-- local modelID = featureBridge.getObjectModelID(spot)
		-- local cmd = RemoveObjectCommand("feature", modelID)
		-- SB.commandManager:execute(cmd)
	-- end
end

function MexManagerListenerWidget:onMexChange(ID, mex)
end