use std::{
    fs::{self, OpenOptions},
    io::Write,
    path::{Path, PathBuf},
};

use spring_native::prelude::NativeInterfaceRef;

pub(super) struct HistoryStore {
    path: PathBuf,
}

impl HistoryStore {
    pub(super) fn new(interface: &NativeInterfaceRef) -> Self {
        let path = history_path(interface);
        log::debug!("native chonsole history: {}", path.display());
        HistoryStore { path }
    }

    pub(super) fn load(&self) -> Vec<String> {
        let raw = match fs::read_to_string(&self.path) {
            Ok(raw) => raw,
            Err(err) if err.kind() == std::io::ErrorKind::NotFound => return Vec::new(),
            Err(err) => {
                log::warn!("read chonsole history {}: {err}", self.path.display());
                return Vec::new();
            }
        };
        raw.lines()
            .map(str::trim)
            .filter(|line| !line.is_empty())
            .map(ToOwned::to_owned)
            .collect()
    }

    pub(super) fn append(&self, entries: &[String]) {
        if entries.is_empty() {
            return;
        }
        if let Some(parent) = self.path.parent() {
            if let Err(err) = fs::create_dir_all(parent) {
                log::warn!("create chonsole history dir {}: {err}", parent.display());
                return;
            }
        }
        let mut file = match OpenOptions::new()
            .create(true)
            .append(true)
            .open(&self.path)
        {
            Ok(file) => file,
            Err(err) => {
                log::warn!("open chonsole history {}: {err}", self.path.display());
                return;
            }
        };
        for entry in entries {
            if let Err(err) = writeln!(file, "{entry}") {
                log::warn!("append chonsole history {}: {err}", self.path.display());
                return;
            }
        }
    }

    pub(super) fn rewrite(&self, history: &[String]) {
        if let Some(parent) = self.path.parent() {
            if let Err(err) = fs::create_dir_all(parent) {
                log::warn!("create chonsole history dir {}: {err}", parent.display());
                return;
            }
        }
        let text = if history.is_empty() {
            String::new()
        } else {
            format!("{}\n", history.join("\n"))
        };
        if let Err(err) = fs::write(&self.path, text) {
            log::warn!("rewrite chonsole history {}: {err}", self.path.display());
        }
    }
}

fn history_path(interface: &NativeInterfaceRef) -> PathBuf {
    if let Some(path) = std::env::var_os("SBC_CHONSOLE_HISTORY") {
        return PathBuf::from(path);
    }
    if let Some(path) = std::env::var_os("SBC_COMMAND_LOG")
        .map(PathBuf::from)
        .and_then(|path| path.parent().map(Path::to_path_buf))
    {
        return path.join(".console_history");
    }
    if let Ok(Some(script)) = interface.vfs().get_file_absolute_path("script.txt", "") {
        if let Some(parent) = Path::new(&script).parent() {
            return parent.join(".console_history");
        }
    }
    PathBuf::from(".console_history")
}

#[cfg(test)]
mod tests {
    use super::HistoryStore;
    use std::fs;

    #[test]
    fn history_store_appends_loads_and_clears() {
        let path =
            std::env::temp_dir().join(format!("sbc_chonsole_history_{}", std::process::id()));
        let _ = fs::remove_file(&path);
        let store = HistoryStore { path: path.clone() };
        store.append(&["/help".to_string(), "plain chat".to_string()]);
        assert_eq!(store.load(), vec!["/help", "plain chat"]);
        store.rewrite(&[]);
        assert_eq!(fs::read_to_string(&path).unwrap(), "");
        let _ = fs::remove_file(&path);
    }
}
