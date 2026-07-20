//! The top-left project status bar: it shows where the current project lives
//! and exposes the always-available actions the launcher used to own (Exit,
//! open the project folder, open the write-data dir, upload the log).
//!
//! Modularity: the higher level owns a single `#project-status-root` div in the
//! panel document; everything else — markup, wiring, and the effects — lives
//! here. The panel manager only renders the caption each frame and forwards any
//! queued actions, so this feature stays self-contained.

mod upload;

use std::cell::RefCell;
use std::path::{Path, PathBuf};
use std::rc::Rc;

use spring_native::prelude::{Error, NativeInterfaceRef};

use crate::sbc::command_system::command::Command;
use crate::sbc::command_system::model::Models;
use crate::sbc::notifications::NotificationManager;
use crate::sbc::project::ProjectManager;
use crate::sbc::rml::{element_by_id, escape_rml};

pub(crate) use upload::UploadLogCommand;

const ROOT_ID: &str = "project-status-root";
const LABEL_ID: &str = "project-status-label";

#[derive(Clone, Copy)]
enum StatusBarAction {
    Exit,
    OpenProject,
    DataDir,
    UploadLog,
}

/// One button in the bar: its element id and the action it queues.
const BUTTONS: [(&str, &str, StatusBarAction); 4] = [
    (
        "project-status-open",
        "Open Project",
        StatusBarAction::OpenProject,
    ),
    ("project-status-data", "Data Dir", StatusBarAction::DataDir),
    (
        "project-status-upload",
        "Upload Log",
        StatusBarAction::UploadLog,
    ),
    ("project-status-exit", "Exit", StatusBarAction::Exit),
];

#[derive(Default)]
pub(crate) struct ProjectStatusBar {
    actions: Rc<RefCell<Vec<StatusBarAction>>>,
    /// Set once the markup and listeners are installed in the live document.
    /// Cleared by `forget` when a reload throws that document away.
    bound: bool,
    last_caption: Option<String>,
}

impl ProjectStatusBar {
    /// The document was destroyed (reload): drop every cached bit of state so
    /// the next `render` rebuilds against the fresh document.
    pub(crate) fn forget(&mut self) {
        self.bound = false;
        self.last_caption = None;
        self.actions.borrow_mut().clear();
    }

    /// Install the bar the first time, then keep its caption in sync.
    pub(crate) fn render(
        &mut self,
        interface: &NativeInterfaceRef,
        document: u64,
        models: &mut Models,
    ) -> Result<(), Error> {
        if !self.bound {
            self.build(interface, document)?;
            self.bound = true;
        }
        let caption = caption(models);
        if self.last_caption.as_deref() != Some(caption.as_str()) {
            if let Some(label) = element_by_id(interface, document, LABEL_ID) {
                interface
                    .rml_ui()
                    .element_set_inner_rml(label, &escape_rml(&caption))?;
            }
            self.last_caption = Some(caption);
        }
        Ok(())
    }

    /// Run whatever the user clicked. Synchronous effects happen here; the log
    /// upload is returned as a command so it can queue background IO.
    pub(crate) fn process(
        &mut self,
        interface: &NativeInterfaceRef,
        models: &mut Models,
    ) -> Vec<Box<dyn Command>> {
        let mut commands: Vec<Box<dyn Command>> = Vec::new();
        for action in self.actions.borrow_mut().drain(..) {
            match action {
                StatusBarAction::Exit => {
                    let _ = interface.messages().send_commands("quitforce", "");
                }
                StatusBarAction::OpenProject => match models.get::<ProjectManager>().path() {
                    Some(path) => open_in_file_manager(Path::new(path)),
                    None => models.get::<NotificationManager>().warn(
                        "project-folder",
                        "Save the project first to open its folder",
                    ),
                },
                StatusBarAction::DataDir => open_in_file_manager(&write_dir()),
                StatusBarAction::UploadLog => {
                    models.get::<NotificationManager>().progress(
                        "upload-log",
                        0.1,
                        "Uploading log...",
                    );
                    commands.push(Box::new(UploadLogCommand::new(log_path())));
                }
            }
        }
        commands
    }

    fn build(&self, interface: &NativeInterfaceRef, document: u64) -> Result<(), Error> {
        let Some(root) = element_by_id(interface, document, ROOT_ID) else {
            return Ok(());
        };
        let mut html = format!(r#"<div class="project-status-label" id="{LABEL_ID}"></div>"#);
        html.push_str(r#"<div class="project-status-buttons">"#);
        for (id, caption, _) in BUTTONS {
            let danger = if id == "project-status-exit" {
                " danger"
            } else {
                ""
            };
            html.push_str(&format!(
                r#"<button id="{id}" class="project-status-btn{danger}">{caption}</button>"#
            ));
        }
        html.push_str("</div>");
        interface.rml_ui().element_set_inner_rml(root, &html)?;

        for (id, _, action) in BUTTONS {
            let Some(button) = element_by_id(interface, document, id) else {
                continue;
            };
            let queue = self.actions.clone();
            interface
                .rml_ui()
                .element_add_event_listener(button, "click", false, move || {
                    queue.borrow_mut().push(action);
                })?;
        }
        Ok(())
    }
}

/// The engine's write-data dir, taken from its own `--write-dir` argv (the
/// plugin shares the engine process). Falls back to the working directory.
pub(crate) fn write_dir() -> PathBuf {
    let mut args = std::env::args();
    while let Some(arg) = args.next() {
        if let Some(rest) = arg.strip_prefix("--write-dir=") {
            return PathBuf::from(rest);
        }
        if arg == "--write-dir" {
            if let Some(next) = args.next() {
                return PathBuf::from(next);
            }
        }
    }
    std::env::current_dir().unwrap_or_default()
}

fn caption(models: &mut Models) -> String {
    match models.get::<ProjectManager>().path() {
        Some(path) => format!("Project: {path}"),
        None => "Project not saved".to_string(),
    }
}

fn log_path() -> PathBuf {
    write_dir().join("infolog.txt")
}

fn open_in_file_manager(path: &Path) {
    let opener = if cfg!(target_os = "macos") {
        "open"
    } else if cfg!(target_os = "windows") {
        "explorer"
    } else {
        "xdg-open"
    };
    if let Err(err) = std::process::Command::new(opener).arg(path).spawn() {
        log::warn!("could not open {}: {err}", path.display());
    }
}
