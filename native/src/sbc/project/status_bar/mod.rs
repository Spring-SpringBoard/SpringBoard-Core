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
use std::time::{Duration, Instant};

use spring_native::prelude::{Error, NativeInterfaceRef};

use crate::sbc::command_system::command::Command;
use crate::sbc::command_system::model::Models;
use crate::sbc::notifications::NotificationManager;
use crate::sbc::project::ProjectManager;
use crate::sbc::rml::{element_by_id, escape_rml};

pub(crate) use upload::UploadLogCommand;

const ROOT_ID: &str = "project-status-root";
const LABEL_ID: &str = "project-status-label";
const OPEN_ID: &str = "project-status-open";

/// A second Upload Log click within this window confirms the (public) upload.
const UPLOAD_CONFIRM_WINDOW: Duration = Duration::from_secs(6);

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
    /// When the first Upload Log click armed the confirmation; a second click
    /// within [`UPLOAD_CONFIRM_WINDOW`] actually uploads.
    upload_armed: Option<Instant>,
}

impl ProjectStatusBar {
    /// The document was destroyed (reload): drop every cached bit of state so
    /// the next `render` rebuilds against the fresh document.
    pub(crate) fn forget(&mut self) {
        self.bound = false;
        self.last_caption = None;
        self.upload_armed = None;
        self.actions.borrow_mut().clear();
    }

    /// Install the bar the first time, then keep its caption and the enabled
    /// state of Open Project (needs a saved project) in sync.
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
        let has_project = models.get::<ProjectManager>().path().is_some();
        let caption = caption(models);
        if self.last_caption.as_deref() != Some(caption.as_str()) {
            if let Some(label) = element_by_id(interface, document, LABEL_ID) {
                interface
                    .rml_ui()
                    .element_set_inner_rml(label, &escape_rml(&caption))?;
            }
            if let Some(open) = element_by_id(interface, document, OPEN_ID) {
                interface
                    .rml_ui()
                    .element_set_class(open, "disabled", !has_project)?;
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
                    // Uploading publishes the full log, so confirm on a second
                    // click rather than firing on the first.
                    let now = Instant::now();
                    let armed = self
                        .upload_armed
                        .is_some_and(|at| now.duration_since(at) < UPLOAD_CONFIRM_WINDOW);
                    if armed {
                        self.upload_armed = None;
                        models.get::<NotificationManager>().progress(
                            "upload-log",
                            0.1,
                            "Uploading log...",
                        );
                        commands.push(Box::new(UploadLogCommand::new(log_path())));
                    } else {
                        self.upload_armed = Some(now);
                        models.get::<NotificationManager>().warn(
                            "upload-log",
                            "This uploads your full log publicly. Click Upload Log again to confirm.",
                        );
                    }
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

/// The engine's write-data dir, where `infolog.txt`, projects and exports live.
///
/// `std::env::args()` is unreliable here: this plugin is `dlopen`ed into the
/// engine, so the Rust runtime never captured argv and the list is usually
/// empty. Resolve from the environment the launcher/harness sets instead:
/// `SBC_WRITE_DIR`, then the dir holding `SBC_COMMAND_LOG`
/// (`<write_dir>/commands.jsonl`), then `--write-dir` if argv happens to be
/// present, and only as a last resort the working directory — never a path that
/// is not a directory (which is how the engine binary once leaked through).
pub(crate) fn write_dir() -> PathBuf {
    let dir = resolve_write_dir(
        std::env::var_os("SBC_WRITE_DIR").map(PathBuf::from),
        std::env::var_os("SBC_COMMAND_LOG").map(PathBuf::from),
        write_dir_from_argv(),
        std::env::current_dir().ok(),
    );
    log::debug!("SBC write dir resolved to {}", dir.display());
    dir
}

/// Pick the first candidate that names a real directory. `command_log` is
/// `<write_dir>/commands.jsonl`, so its parent is the write dir. The `is_dir`
/// guard is what stops a stray non-directory (the engine binary once leaked in
/// via argv) from being treated as the data dir.
fn resolve_write_dir(
    sbc_write_dir: Option<PathBuf>,
    command_log: Option<PathBuf>,
    argv_dir: Option<PathBuf>,
    cwd: Option<PathBuf>,
) -> PathBuf {
    let command_log_dir = command_log.and_then(|log| log.parent().map(Path::to_path_buf));
    [sbc_write_dir, command_log_dir, argv_dir, cwd]
        .into_iter()
        .flatten()
        .find(|path| path.is_dir())
        .unwrap_or_default()
}

fn write_dir_from_argv() -> Option<PathBuf> {
    let mut args = std::env::args();
    while let Some(arg) = args.next() {
        if let Some(rest) = arg.strip_prefix("--write-dir=") {
            return Some(PathBuf::from(rest));
        }
        if arg == "--write-dir" {
            return args.next().map(PathBuf::from);
        }
    }
    None
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

#[cfg(test)]
mod tests {
    use super::resolve_write_dir;
    use std::path::PathBuf;

    #[test]
    fn command_log_parent_is_the_write_dir() {
        let dir = std::env::temp_dir();
        let log = dir.join("commands.jsonl");
        let resolved = resolve_write_dir(None, Some(log), None, None);
        assert_eq!(resolved, dir);
    }

    #[test]
    fn a_non_directory_candidate_is_skipped_for_a_real_one() {
        // The bug: argv handed us the engine binary (a file). It must be passed
        // over in favour of a real directory, never returned.
        let binary = PathBuf::from("/definitely/not/a/dir/spring");
        let dir = std::env::temp_dir();
        let resolved = resolve_write_dir(None, None, Some(binary), Some(dir.clone()));
        assert_eq!(resolved, dir);
    }

    #[test]
    fn explicit_override_wins() {
        let dir = std::env::temp_dir();
        let resolved = resolve_write_dir(Some(dir.clone()), None, None, None);
        assert_eq!(resolved, dir);
    }
}
