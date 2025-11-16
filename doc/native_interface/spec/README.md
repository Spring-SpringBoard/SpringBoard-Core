# Native Interface Specification

The native interface mirrors the existing Lua-facing APIs. Each specification file corresponds to a legacy Lua module and documents:

- Data types exposed across the boundary
- Native function signatures
- Status and notes for the ongoing port

Available sections:

- [ConstCMD API](ConstCMD.md)
- [ConstCMDTYPE API](ConstCMDTYPE.md)
- [ConstCOB API](ConstCOB.md)
- [ConstEngine API](ConstEngine.md)
- [ConstGame API](ConstGame.md)
- [ConstGL API](ConstGL.md)
- [ConstPlatform API](ConstPlatform.md)
- [Encoding API](Encoding.md)
- [MathExtra API](MathExtra.md)
- [MetalMap API](MetalMap.md)
- [SyncedCtrl API](SyncedCtrl.md)
- [TracyExtra API](TracyExtra.md)
- [UICommand API](UICommand.md)

## Specification Status

- Archive — pending (Expose VFS archive functions (LuaArchive::PushEntries).)
- AtlasTextures — helper (Internal texture-atlas utilities used by LuaOpenGL; no direct Lua table.)
- ConstCMD — documented (see `ConstCMD.md` for command IDs and option flags).
- ConstCMDTYPE — documented (see `ConstCMDTYPE.md` for command cursor/argument modes).
- ConstCOB — documented (COB script constants and SFX flags, see `ConstCOB.md`).
- ConstEngine — documented (engine metadata and feature flags, see `ConstEngine.md`).
- ConstGame — documented (game/map/mod metadata, see `ConstGame.md`).
- ConstGL — documented (OpenGL enumeration mirror, see `ConstGL.md`).
- ConstPlatform — documented (runtime hardware info, see `ConstPlatform.md`).
- Encoding — documented (see `Encoding.md` for native base64 helpers).
- FBOs — pending (Framebuffer helpers (LuaFBOs::PushEntries).)
- FeatureDefs — pending (Feature definition accessors (LuaFeatureDefs::PushEntries).)
- Fonts — pending (Font API (LuaFonts::PushEntries).)
- Gaia — helper (Lua handle loader (CLuaGaia); no standalone API.)
- Handle — helper (Core Lua runtime infrastructure (LuaHandle).)
- HandleSynced — helper (Synced handle plumbing; not a standalone API surface.)
- InputReceiver — helper (C++ UI input integration; no Lua tables exposed.)
- InterCall — pending (Script cross-call helpers (LuaInterCall::PushEntries*).)
- Intro — pending (Intro script API (LuaIntro::PushEntries).)
- IO — helper (LuaIO utilities used internally.)
- Material — helper (Material system support (LuaMaterial) without direct tables.)
- MathExtra — documented (see `MathExtra.md` for math extensions).
- MemPool — helper (Memory pool management (LuaMemPool).)
- Menu — pending (Menu script API (LuaMenu::PushEntries).)
- MetalMap — documented (see `MetalMap.md` for native mapping).
- ObjectRendering — helper (Rendering helpers consumed by other APIs.)
- OpenGL — pending (Core GL bindings (LuaOpenGL::PushEntries).)
- OpenGLUtils — helper (Utility functions backing LuaOpenGL.)
- Parser — pending (LuaParser interface (LuaParser::PushEntries).)
- PathFinder — pending (Path finder queries (LuaPathFinder::PushEntries).)
- RBOs — pending (Renderbuffer helpers (LuaRBOs::PushEntries).)
- Rules — pending (LuaRules engine bridge (LuaRules::PushEntries).)
- RulesParams — helper (Data structures for rules params (no PushEntries).)
- Scream — pending (Sound/notification API (LuaScream::PushEntries).)
- Shaders — pending (Shader management (LuaShaders::PushEntries).)
- SyncedCtrl — in progress (Spec started (`SyncedCtrl.md`); large control surface pending completion.)
- SyncedMoveCtrl — pending (Spring.MoveCtrl table (LuaSyncedMoveCtrl::PushMoveCtrl).)
- SyncedRead — pending (Synced read access (LuaSyncedRead::PushEntries).)
- SyncedTable — pending (Utility tables for synced code (LuaSyncedTable::PushEntries).)
- TableExtra — pending (Extra table helpers (LuaTableExtra::PushEntries).)
- Textures — helper (Texture helpers consumed by other modules.)
- TracyExtra — documented (see `TracyExtra.md` for profiler helpers).
- UI — pending (LuaUI bridge (LuaUI::PushEntries).)
- UICommand — documented (see `UICommand.md` for UI command listings).
- UnitDefs — pending (Unit definition access (LuaUnitDefs::PushEntries).)
- UnsyncedCtrl — pending (Unsynced control surface (LuaUnsyncedCtrl::PushEntries).)
- UnsyncedRead — pending (Unsynced read API (LuaUnsyncedRead::PushEntries).)
- Utils — helper (General Lua utilities (LuaUtils).)
- VAO — pending (Vertex array object API (LuaVAO::PushEntries).)
- VAOImpl — helper (Implementation backing LuaVAO.)
- VBO — pending (Vertex buffer object API (LuaVBO::PushEntries).)
- VBOImpl — helper (Implementation backing LuaVBO.)
- VFS — helper (Core VFS helpers (no direct Lua table).)
- VFSDownload — pending (Download helpers (LuaVFSDownload::PushEntries).)
- WeaponDefs — pending (Weapon definition access (LuaWeaponDefs::PushEntries).)
- Zip — helper (Zip utilities (LuaZip).)

Additional sections will be added as the audit expands.

## Native Mapping
- _To be defined._

