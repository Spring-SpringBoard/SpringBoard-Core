Graphics = LCS.class{}

SB.IncludeDir(Path.Join(SB.DIRS.SRC, 'gfx'))
SB.IncludeDir(Path.Join(SB.DIRS.SRC, 'gfx/draw'))

function Graphics:init()
    self:__InitTempTextures()
end