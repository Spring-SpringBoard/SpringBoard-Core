ExportS11NCommand = Command:extends{}
ExportS11NCommand.className = "ExportS11NCommand"

function ExportS11NCommand:init(path)
    self.className = "ExportS11NCommand"
    self.path = path
	--add extension if it doesn't exist
	if Path.GetExt(self.path) ~= SB_S11N_EXT then
		self.path = self.path .. SB_S11N_EXT
	end
end

function ExportS11NCommand:execute()
    Time.MeasureTime(function()
        local model = {}

        for name, objectS11N in pairs(s11n.s11nByName) do
            model[name] = objectS11N:Get()
        end

        table.save(model, self.path)
    end, function(elapsed)
        Log.Notice(("[%.4fs] Exported S11N model"):format(elapsed))
    end)
end
