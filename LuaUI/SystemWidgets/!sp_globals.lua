if addon.InGetInfo then
	return {
        name      = "sb_globals",
        author    = "gajop",
        license   = "MIT",
        layer     = -9999999999,
        enabled   = true,
        api       = true,
        hidden    = true,
	}
end

-- For widgets SG = WG
handler.SG.SB_LIBS_DIR = "libs_sb/"
handler.SG.SB = {}
