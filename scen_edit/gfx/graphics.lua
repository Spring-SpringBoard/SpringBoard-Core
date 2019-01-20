Graphics = LCS.class{}

SB_GFX_DIR = Path.Join(SB_DIR, "gfx/")
SB_GFX_DRAW_DIR = Path.Join(SB_GFX_DIR, "draw/")

SB.IncludeDir(SB_GFX_DIR)
SB.IncludeDir(SB_GFX_DRAW_DIR)

function Graphics:init()
    self:__InitTempTextures()
end