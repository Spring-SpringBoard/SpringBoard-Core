//! [`Action`] — the pure metadata of every toolbar/hotkey action (caption,
//! icon, shortcut). The logic that runs each one lives in [`super::run`].

/// Every action the editor knows about. Some appear as toolbar buttons (listed
/// in [`Action::TOOLBAR`]); the rest are hotkey-only.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum Action {
    NewProject,
    Load,
    Import,
    Save,
    SaveAs,
    Export,
    Copy,
    Cut,
    Paste,
    Undo,
    Redo,
    Delete,
    SelectAll,
    SelectSameType,
    SelectSameTypeInView,
}

impl Action {
    /// The stable name used by the programmatic dialog API for actions that
    /// collect file/project input.
    pub fn dialog_name(self) -> Option<&'static str> {
        match self {
            Action::NewProject => Some("new_project"),
            Action::Load => Some("load_project"),
            Action::Import => Some("import"),
            Action::SaveAs => Some("save_project_as"),
            Action::Export => Some("export"),
            _ => None,
        }
    }

    pub fn from_dialog_name(name: &str) -> Option<Self> {
        match name {
            "new_project" => Some(Action::NewProject),
            "load_project" => Some(Action::Load),
            "import" => Some(Action::Import),
            "save_project_as" => Some(Action::SaveAs),
            "export" => Some(Action::Export),
            _ => None,
        }
    }

    /// All actions, in a stable order.
    pub const ALL: [Action; 15] = [
        Action::NewProject,
        Action::Load,
        Action::Import,
        Action::Save,
        Action::SaveAs,
        Action::Export,
        Action::Copy,
        Action::Cut,
        Action::Paste,
        Action::Undo,
        Action::Redo,
        Action::Delete,
        Action::SelectAll,
        Action::SelectSameType,
        Action::SelectSameTypeInView,
    ];

    /// Actions shown as toolbar buttons, in bar order.
    pub const TOOLBAR: [Action; 9] = [
        Action::NewProject,
        Action::Load,
        Action::Import,
        Action::Save,
        Action::SaveAs,
        Action::Export,
        Action::Copy,
        Action::Cut,
        Action::Paste,
    ];

    pub fn tooltip(&self) -> &'static str {
        match self {
            Action::NewProject => "New project",
            Action::Load => "Load Project",
            Action::Import => "Import",
            Action::Save => "Save project",
            Action::SaveAs => "Save project as...",
            Action::Export => "Export",
            Action::Copy => "Copy",
            Action::Cut => "Cut",
            Action::Paste => "Paste",
            Action::Undo => "Undo",
            Action::Redo => "Redo",
            Action::Delete => "Delete",
            Action::SelectAll => "Select all",
            Action::SelectSameType => "Select same type",
            Action::SelectSameTypeInView => "Select same type in view",
        }
    }

    pub fn icon(&self) -> Option<&'static str> {
        let name = match self {
            Action::NewProject => "LuaUI/images/scenedit/file.png",
            Action::Load => "LuaUI/images/scenedit/open-folder.png",
            Action::Import => "LuaUI/images/scenedit/open-folder.png",
            Action::Save => "LuaUI/images/scenedit/save.png",
            Action::SaveAs => "LuaUI/images/scenedit/save.png",
            Action::Export => "LuaUI/images/scenedit/save.png",
            Action::Copy => "LuaUI/images/scenedit/copy.png",
            // The toolbar variant has the opaque, high-contrast glyph. The
            // root image is mostly transparent at toolbar scale and read as a
            // missing Cut icon in RmlUi.
            Action::Cut => "LuaUI/images/scenedit/modifications/scissors-rotated.png",
            Action::Paste => "LuaUI/images/scenedit/stabbed-note.png",
            // Undo/Redo have no icon in Lua either (filtered from toolbar).
            _ => return None,
        };
        Some(name)
    }

    pub fn hotkey(&self) -> Option<Hotkey> {
        Some(match self {
            Action::NewProject => Hotkey::new("n", true, false),
            Action::Load => Hotkey::new("o", true, false),
            Action::Import => Hotkey::new("i", true, false),
            Action::Save => Hotkey::new("s", true, false),
            Action::SaveAs => Hotkey::new("s", true, true),
            Action::Export => Hotkey::new("e", true, false),
            Action::Copy => Hotkey::new("c", true, false),
            Action::Cut => Hotkey::new("x", true, false),
            Action::Paste => Hotkey::new("v", true, false),
            Action::Undo => Hotkey::new("z", true, false),
            Action::Redo => Hotkey::new("y", true, false),
            Action::Delete => Hotkey::new("delete", false, false),
            Action::SelectAll => Hotkey::new("a", true, false),
            Action::SelectSameType => Hotkey::new("t", true, false),
            Action::SelectSameTypeInView => Hotkey::new("t", true, true),
        })
    }
}

/// A keyboard shortcut. `key` is a Spring key name resolved by `is_key`.
#[derive(Debug, Clone, Copy)]
pub struct Hotkey {
    pub key: &'static str,
    pub ctrl: bool,
    pub shift: bool,
}

impl Hotkey {
    pub const fn new(key: &'static str, ctrl: bool, shift: bool) -> Self {
        Hotkey { key, ctrl, shift }
    }
}
