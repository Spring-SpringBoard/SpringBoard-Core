return {
    functions = {
        {
            name = "GOD_MODE_ENABLED",
            humanName = "God mode enabled",
            output = "bool",
            tags = { "Game State" },
            execute = function(input)
                return Spring.IsGodModeEnabled()
            end
        },
        {
            name = "CHEATING_ENABLED",
            humanName = "Cheating enabled",
            output = "bool",
            tags = { "Game State" },
            execute = function(input)
                return Spring.IsCheatingEnabled()
            end
        },
        {
            name = "HELPER_AIS_ENABLED",
            humanName = "Helper AIs enabled",
            output = "bool",
            tags = { "Game State" },
            execute = function(input)
                return Spring.AreHelperAIsEnabled()
            end
        },
        {
            name = "FIXED_ALLIES",
            humanName = "Fixed allies",
            output = "bool",
            tags = { "Game State" },
            execute = function(input)
                return Spring.FixedAllies()
            end
        },
        {
            name = "GAME_OVER",
            humanName = "Game over",
            output = "bool",
            tags = { "Game State" },
            execute = function(input)
                return Spring.IsGameOver()
            end
        },

        {
            name = "GAME_SPEED",
            humanName = "Game speed",
            output = "number",
            tags = { "Time" },
            execute = function(input)
                return Spring.GetGameSpeed()
            end
        },
        {
            name = "GAME_FRAME",
            humanName = "Game frame",
            output = "number",
            tags = { "Time" },
            execute = function(input)
                return Spring.GetGameFrame()
            end
        },
        {
            name = "GAME_SECONDS",
            humanName = "Game seconds",
            output = "number",
            tags = { "Time" },
            execute = function(input)
                return Spring.GetGameSeconds()
            end
        },
        {
            name = "INTEGER_RANDOM",
            humanName = "Random",
            input = {
                {
                    name = "min", 
                    humanName = "Min",
                    type = "number",
                },
                {
                    name = "max", 
                    humanName = "Max",
                    type = "number",
                },
            },
            output = "number",
            execute = function(input)
                return math.random(input.min, input.max)
            end
        },
    }
}
