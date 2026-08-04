TraceScreenRayParityCommand = Command:extends{}
TraceScreenRayParityCommand.className = "TraceScreenRayParityCommand"

function TraceScreenRayParityCommand:init(token, points)
    self.token = token
    self.points = points
end

function TraceScreenRayParityCommand:execute()
    local results = {}
    for index, point in ipairs(self.points) do
        local kind, coords = Spring.TraceScreenRay(point[1], point[2], true, false, false, true, 0)
        results[index] = {
            kind = kind,
            coords = coords,
        }
    end
    Spring.InvokeNativeModule(json.encode({
        tag = "trace_screen_ray_parity",
        data = {
            token = self.token,
            results = results,
        },
    }))
end
