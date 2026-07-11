*CRITICAL* Instructions for AI: When editing this file, you can _ONLY_ mark things as [DONE] at the left-most part of the line. You can also remove [DONE] if you realize that any of the things listed as DONE actually isn't done. You cannot alter any text outside of that.

Basic controls:
[NOT FIXED]- Numeric: if I click and drag, and release the mouse button outside of the control, it doesn't seem to actually release it. If I keep dragging after I released the mouse button, it will still keep changing values, as if I'm in the click+drag mode still.
[PARTIALLY FIXED]- Tooltips appear but I think you didn't add all the tooltips we had originally

Object->Properties
[NOT FIXED - missing a lot of separators original had]- Object properties are missing a LOT of fields. I won't even bother enumerating all the stuff that's missing, as there's a ton. You must look at how Lua does it.

Object->Unit/Features issues:
[NOT FIXED]- Add/Brush is missing numerous numeric settings, see original chili
- This is still a problem and it affects most brushes (terrain too). Features add is not correctly ray-tracing. It's almost as if mouse Y is inverse?
[NOT FIXED - poor preview, doesn't have feature texture]- Features add is not actually previewing the to-be-placed feature; It's rendering some strange green circle. The green circle might be an OK addition to the ChiliUI one, and would help with geovents and similar features with no preview - but it's not OK to replace the actual feature rendering.
[NOT FIXED]- Seems like there are two selection systems going on. If I click on the feature directly, there's this new yellow-ish circle, but if I do a drag select there's a green rectangle (potentially some Chili relic? I can't tell)
[NOT FIXED]  - There should be only one selection active. If Chili/Lua still has something going on, that should be disabled when in rust mode. Likewise, I don't think you need to reinvent this, rendering it behind the feature as a rectangle was fine. The orange one is a different color (needlessly) and most importantly, doesn't even render right (needs to render _below_, not above units/features). The orange one also doesn't seem to work with multi-select, and I can't seem to deselect things by clicking ESC
[NOT FIXED]  - With that in mind, make sure you implement proper object selection in rust. I assume you didn't do this right.

Map->Settings
[NOT FIXED - texture settings aren't just check boxes.. they are meant to allow you to choose/create textures]- Settings are probably missing a TON of fields too, this is also half-assed. See Lua.

Map->Terrain:
- (This is still odd, because you are ALSO showing a dialog, which isn't needed) The pattern selection in Add/Set/Smooth should be expanded, and not a dialog.
- Pattern selection doesn't allow you to change folders, normal asset view in Chili / Lua did
-
[NOT FIXED]- Selecting the terrain should send this info as a command, but that's not happening. So if I do pattern selection and then try clicking on map, I get errors.. This is basic control.
[Not FIXED - super pixelated images? sampling is wrong]- Terrain->Add shows this weird rendering when mouse-over the map. This is wrong.. again .. why are you doing this differently? Lua already has a working, better implementation, that properly draws it based on the image alpha. We have ways of loading images, this code already exists in commands. Do not reimplement this! Reuse the loading mechanism (maybe move it to a more appropriate place), if you need it. You might also not need it, since you don't need to load it as bytes (but instead texture), and in that case, just do it like Lua did it originally.

Map->Paint:
[NOT FIXED - you don't understand the original at all, wtf is this?]  - Doesn't understand textures: paint textures consist of diffuse, specular, normal, etc. Those are normally represented as separate channels and are different files. Tooltip also existed to tell you which channels exist.
[NOT FIXED]  - Doesn't work, cannot paint diffuse/specular/anything really...
[NOT FIXED]- Original properly detected DNTS - to disable it

Map->Metal:
[NOT FIXED]- Cannot paint, probably because you aren't loading textures right(sending the SetHeightmapBrushCommand properly). This also gives errors

Misc->Teams
[NOT FIXED]- WTF is this? doesn't look like the original at all, original had each team as a dialog?

Action icons:
- (This wasn't fixed) I cannot click the New Project dialog button if I click at the top. All of them really. It seems the hit box (clickable area) is much smaller than the icon.

Dev console:
- Buttons still seem significantly smaller (width vise) than the original, and text feels misaligned

Status panel:
- Original status panel that showed memory/cpu usage, and showed recently executed commands isn't ported yet