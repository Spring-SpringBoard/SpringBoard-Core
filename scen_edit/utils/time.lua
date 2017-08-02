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
function Time.MeasureTime(f1, f2)
    local timer1 = Spring.GetTimer()
    f1()
    local timer2 = Spring.GetTimer()
    diff = Spring.DiffTimers(timer2, timer1)
    f2(diff)
end
