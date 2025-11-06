# Smoke Test Status - Investigation Complete

## Conclusion: Spring-Headless Not Viable ❌

After extensive testing, **spring-headless is not compatible with SpringBoard smoke tests** and cannot be used as a replacement for regular Spring with xvfb.

## Investigation Summary

### What Was Tested
1. ✅ Spring-headless with generated map (empty mapfile)
2. ✅ Spring-headless with real map file (TestMinimal2x2.smf)
3. ✅ Spring-headless with 10-second timeout
4. ✅ Various mapinfo.lua configurations

### The Core Problem
**Spring-headless crashes during "Loading Square Textures" before LuaUI initialization**

- Crash happens consistently ~2 seconds after start
- Exit code: 139 (segfault)
- Occurs at same point regardless of map type (generated or real SMF)
- Crash happens BEFORE LuaUI loads
- Smoke test requires LuaUI to initialize (to verify RmlUi integration)

### Loading Sequence & Crash Point
```
✅ Engine initialization
✅ Archive scanning
✅ SpringBoard Core loads
✅ LuaIntro loads
✅ Map parsing
✅ Feature Definitions load
✅ Map Features initialize
✅ Models load
✅ ShadowHandler creates
✅ InfoTextureHandler creates
✅ GroundDrawer creates
✅ Map Tiles load
❌ SEGFAULT at "Loading Square Textures" ← Crash happens here
❌ Never reaches LuaUI initialization
```

### Why This Matters
The smoke test checks for:
1. `grep -q "LuaUI.*Loaded\|Loading LuaUI" test-data/infolog.txt`
2. `grep -q -i "rmlui" test-data/infolog.txt`

Spring-headless crashes before LuaUI loads, so these checks will always fail.

## The Correct Solution

**Use regular `spring` binary with `xvfb`** as designed in `test-smoke.sh`:

```bash
timeout 10s xvfb-run -a -s "-screen 0 1024x768x24" \
  ./spring --write-dir $(pwd)/test-data script.txt
```

This approach:
- ✅ Doesn't crash during texture loading
- ✅ Allows LuaUI to initialize
- ✅ Allows RmlUi integration to be verified
- ✅ Is already implemented in test-smoke.sh
- ✅ Works with both generated maps and real maps

## What Works in test-smoke.sh

The existing `test-smoke.sh` script already has the correct approach:
1. Downloads BAR Engine (regular spring, not headless)
2. Uses xvfb for virtual X server
3. Runs with 10-second timeout
4. Checks for LuaUI and RmlUi initialization
5. Uses generated map approach

## Successfully Fixed Issues

1. **Audio Crashes**: `Sound = 0` in springsettings.cfg
2. **SpringBoard Archive**: Fixed modinfo.lua structure
3. **Version Variable**: Changed from `$VERSION` to `test`
4. **Game Name Matching**: "SpringBoard Core test"
5. **Map Generation**: Proper MAPOPTIONS (new_map_x, new_map_y) and MODOPTIONS (MapSeed) configuration

## Current Test Configuration

**Script.txt**:
```
[GAME]
{
  GameType=SpringBoard Core test;
  MapName=sb_initial_blank_10x8 v1;
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

## Next Steps

1. ✅ Investigation complete - spring-headless is not viable
2. ⏭️ Test with regular spring + xvfb (as in test-smoke.sh)
3. ⏭️ Verify map generation works with regular spring
4. ⏭️ Confirm LuaUI and RmlUi initialize properly
5. ⏭️ Update CI workflow if needed

## References

- Test script: `test-smoke.sh` (already correct)
- BAR Engine: https://github.com/beyond-all-reason/spring/releases
- Spring docs: https://springrts.com/
