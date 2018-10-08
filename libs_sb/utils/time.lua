Time = Time or {}

-- Use as:
-- Time.MeasureTime(
--     function()
--         -- doStuff
--     end),
--     function(elapsed)
--         -- use elapsed (in seconds)
--     end)
-- )
function Time.MeasureTime(exec, after)
    local timer1 = Spring.GetTimer()

    exec()

    local timer2 = Spring.GetTimer()
    local diff = Spring.DiffTimers(timer2, timer1)

    after(diff)
end
