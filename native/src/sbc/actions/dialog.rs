//! The values an action hands the manager: what to do next ([`ActionResult`])
//! and how to configure the file browser ([`FileDialogConfig`]).

use spring_native::prelude::NativeInterfaceRef;

use super::paths::PROJECTS_DIR;
use crate::sbc::command_system::command::Command;

/// What an action wants the manager to do.
pub enum ActionResult {
    /// Nothing to do (not executable, or handled internally like selection ops).
    None,
    /// Submit these typed commands directly — no JSON envelope, no `className`,
    /// no producer-assigned id (the command manager allocates one on execute).
    NativeCommands(Vec<Box<dyn Command>>),
    /// Open the file browser. `on_accept` is called with the picked path.
    OpenFileDialog {
        config: FileDialogConfig,
        on_accept: FileAcceptFn,
    },
    /// Open the new-project dialog.
    OpenNewProject,
}

/// Configuration for the file browser dialog.
#[derive(Debug, Clone)]
pub struct FileDialogConfig {
    pub title: String,
    pub root_dir: String,
    /// File extensions to show (e.g. `[".png", ".jpg"]`). Empty = show all.
    pub extensions: Vec<String>,
    /// Show a text input for the user to type a name (Save As).
    pub show_name_input: bool,
    /// Treat directories as selectable items (Open/Save project).
    pub dirs_as_items: bool,
    /// Optional dropdown of named types (Import: Diffuse/Heightmap).
    pub file_types: Vec<String>,
}

impl Default for FileDialogConfig {
    fn default() -> Self {
        FileDialogConfig {
            title: "File".to_string(),
            root_dir: PROJECTS_DIR.to_string(),
            extensions: Vec::new(),
            show_name_input: false,
            dirs_as_items: false,
            file_types: Vec::new(),
        }
    }
}

/// The result of a file dialog confirmation.
#[derive(Debug, Clone)]
pub struct FileDialogResult {
    pub path: String,
    pub file_type: Option<String>,
}

/// A type-erased callback that produces typed commands from a dialog result.
pub type FileAcceptFn =
    Box<dyn FnOnce(&FileDialogResult, &NativeInterfaceRef) -> Vec<Box<dyn Command>>>;
