return {
	actions = {
	    {
		  name = "CHANGE_AREA_HEIGHT",
		  humanName = "Change area height",
		  input = { "area", "number" },
		  execute = function(input)
		      local area = input.area
		      local number = input.number
		      Spring.SetHeightMapFunc(function()
			local x1, x2 = area[1], area[3]
			local z1, z2 = area[2], area[4]
			for x = x1, x2, Game.squareSize do
			  for z = z1, z2, Game.squareSize do
			    Spring.AddHeightMap(x, z, number)
			  end
			end
		      end)
		  end,
	    }
	},
	functions = {
	  {
	    name = "NUMBER_UNIT_TYPES_IN_ARRAY",
	    humanName = "Number of unit types in array",
	    input = { "unit_array", "unitType" },
	    output = "number",
	    execute = function(input)
	      local units = input.unit_array
	      local unitTypeID = input.unitType
	      local count = 0
	      for _, unitID in pairs(units) do
		if Spring.GetUnitDefID(unitID) == unitTypeID then
		  count = count + 1
		end
	      end
	      return count
	    end,
	  }
	},
}

