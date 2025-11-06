# Smoke Test Status

## Current Progress: ~90% Complete

### ✅ Successfully Fixed:
1. **Audio Crashes**: `Sound = 0` in springsettings.cfg completely disables OpenAL  
2. **SpringBoard Archive**: Fixed modinfo.lua structure (must be at archive root)
3. **Version Variable**: Changed from `$VERSION` to `test` for CI
4. **Game Name Matching**: Spring concatenates name + version = "SpringBoard Core test"
5. **Spring-Headless Discovery**: Using `spring-headless --isolation` (from BAR testing)
6. **Map Generation Options**: Added MAPOPTIONS (new_map_x, new_map_y) and MODOPTIONS (MapSeed)

### ❌ Current Blocker: Map Texture Loading

**Issue**: Spring segfaults at "Loading Square Textures" stage

**Root Cause**: The minimal SMF map created doesn't have proper DXT1-compressed .smt texture tile files

**Why This Blocks Everything**: 
- Spring requires valid map WITH textures to load
- LuaUI (which contains RmlUi) only loads AFTER map textures
- Map generation happens in SpringBoard's Lua code AFTER LuaUI loads
- Can't verify RmlUi initialization without getting past texture loading

**What We Tried**:
1. ✗ Mapinfo.lua-only map (Spring requires .smf file)
2. ✗ Minimal .smf with header only (crashes on texture loading)
3. ✗ Using test_blank.sdd with empty mapfile (Spring requires actual file)
4. ✗ Map downloads (403 Forbidden in CI)
5. ✓ Spring-headless (works better but still crashes on textures)

**What We Need**:
- Valid .smt texture files with DXT1 compression, OR
- Access to pre-existing minimal Spring map with working textures, OR  
- Way to make Spring skip texture loading entirely (doesn't exist)

**Creating proper .smt files requires**:
- Image processing libraries (PIL/Pillow) - not available
- DXT1 compression tools (libsquish/nvdxt) - not available
- Or: MapConv tool from Spring ecosystem

## Test Configuration

**Script.txt** (in test-engine/, gitignored):
```
[GAME]
{
  GameType=SpringBoard Core test;
  MapName=TestMinimal2x2 v1.0;
  IsHost=1;
  MyPlayerName=TestPlayer;
  [MAPOPTIONS]
  {
    new_map_x=10;
    new_map_y=8;
  }
  [MODOPTIONS]
  {
    MapSeed=42;
  }
  [PLAYER0]
  {
    Name=TestPlayer;
    Team=0;
    IsFromDemo=0;
    Spectator=1;
  }
  [TEAM0]
  {
    TeamLeader=0;
    AllyTeam=0;
  }
  [ALLYTEAM0]
  {
  }
}
```

**Command**:
```bash
spring-headless --isolation --write-dir /absolute/path/to/test-data script.txt
```

**What Works**:
- SpringBoard Core loads successfully  
- All archives scan properly (285ms vs hanging with symlinks)
- Game initialization completes through "Loading Models"
- Gets to texture loading stage consistently

**Crash Point**:
```
[t=00:00:02.277888] [LoadScreen::SetLoadMessage] text="Loading Square Textures"
Segmentation fault
```

## Next Steps

1. Find/create valid minimal Spring map with proper texture files
2. Or: Package existing small map (if licensing allows)
3. Or: Use Spring map creation tools in CI to generate valid map
4. Once map loads: Verify LuaUI initializes
5. Once LuaUI loads: Verify RmlUi messages in infolog
6. Update CI workflow to use spring-headless with --isolation flag

## References

- BAR headless testing: https://github.com/beyond-all-reason/Beyond-All-Reason/tree/master/tools/headless_testing
- Spring SMF format: https://springrts.com/wiki/Mapdev:SMF_format
- Spring config vars: `./spring --list-config-vars | grep Sound`
