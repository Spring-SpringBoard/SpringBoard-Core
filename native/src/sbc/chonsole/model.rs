use std::{
    any::Any,
    fs::{self, OpenOptions},
    io::Write,
    path::{Path, PathBuf},
};

use serde::Deserialize;
use serde_json::Value;
use spring_native::prelude::{Error, NativeInterfaceRef};

use super::core::{ChatTarget, ChonsoleCore, ChonsoleEffect};
use super::events::{ChonsoleEvents, KeyOutcome};
use super::types::{ChonsoleResponse, ChonsoleSuggestion};
use super::view::ChonsoleView;
use crate::sbc::command_system::model::{Model, ModelFactory};
use crate::sbc::message_handler::MessageHandler;
use crate::sbc::port_flags::{self, PortImpl};
use crate::sbc::sbc::SBC;

inventory::submit! { ModelFactory { make: |iface| Box::new(ChonsoleManager::new(iface)) } }
inventory::submit! { MessageHandler { tag: "chonsole_execute", handler: execute_message } }
inventory::submit! { MessageHandler { tag: "chonsole_suggest", handler: suggest_message } }
inventory::submit! { MessageHandler { tag: "chonsole_history", handler: history_message } }
inventory::submit! { MessageHandler { tag: "chonsole_clear", handler: clear_message } }

pub struct ChonsoleManager {
    interface: NativeInterfaceRef,
    enabled: bool,
    core: ChonsoleCore,
    view: ChonsoleView,
    events: ChonsoleEvents,
    history_store: Option<HistoryStore>,
}

impl Model for ChonsoleManager {
    fn as_any_mut(&mut self) -> &mut dyn Any {
        self
    }
}

impl Drop for ChonsoleManager {
    fn drop(&mut self) {
        if self.enabled {
            self.view.dispose(&self.interface);
        }
    }
}

impl ChonsoleManager {
    pub fn new(interface: NativeInterfaceRef) -> Self {
        let enabled = port_flags::chonsole_impl(&interface) == PortImpl::Rust;
        let history_store = enabled.then(|| HistoryStore::new(&interface));
        let history = history_store
            .as_ref()
            .map(HistoryStore::load)
            .unwrap_or_default();
        log::info!(
            "native chonsole {}",
            if enabled { "enabled" } else { "disabled" }
        );
        ChonsoleManager {
            interface,
            enabled,
            core: ChonsoleCore::with_history(history),
            view: ChonsoleView::default(),
            events: ChonsoleEvents::default(),
            history_store,
        }
    }

    pub fn execute(&mut self, input: &str) -> ChonsoleResponse {
        if !self.enabled {
            return ChonsoleResponse {
                input: input.to_string(),
                lines: Vec::new(),
                history: self.core.history().to_vec(),
            };
        }
        let before_history_len = self.core.history().len();
        let (response, effects) = self.core.execute(input);
        self.persist_history_change(before_history_len);
        for effect in effects {
            self.apply(effect);
        }
        self.view.apply_response(&response, &self.core);
        self.events.reset_history_cursor();
        let _ = self.view.refresh(&self.interface, &self.core);
        response
    }

    pub fn suggestions(&self, input: &str) -> Vec<ChonsoleSuggestion> {
        if !self.enabled {
            return Vec::new();
        }
        self.core.suggestions(input)
    }

    pub fn history(&self) -> &[String] {
        self.core.history()
    }

    pub fn clear(&mut self) {
        if !self.enabled {
            return;
        }
        self.core.clear();
        if let Some(store) = &self.history_store {
            store.rewrite(self.core.history());
        }
        self.view.clear();
        self.events.reset_history_cursor();
        let _ = self.view.refresh(&self.interface, &self.core);
    }

    pub fn update(&mut self) -> Result<(), Error> {
        if !self.enabled {
            return Ok(());
        }
        self.view.ensure(&self.interface)?;
        self.view.update(&self.interface)
    }

    pub fn draw_screen(&mut self) -> Result<(), Error> {
        if !self.enabled {
            return Ok(());
        }
        self.view.draw_screen(&self.interface)
    }

    pub fn key_press(
        &mut self,
        key_code: i32,
        scan_code: i32,
        is_repeat: bool,
    ) -> Result<bool, Error> {
        if !self.enabled {
            return Ok(false);
        }
        match self.events.key_press(
            &self.interface,
            &self.core,
            &mut self.view,
            key_code,
            scan_code,
            is_repeat,
        )? {
            KeyOutcome::Unhandled => Ok(false),
            KeyOutcome::Handled => Ok(true),
            KeyOutcome::Execute(input) => {
                self.execute(&input);
                self.view.set_visible(&self.interface, false)?;
                Ok(true)
            }
        }
    }

    pub fn key_release(&mut self, key_code: i32, scan_code: i32) -> Result<bool, Error> {
        if !self.enabled {
            return Ok(false);
        }
        self.events
            .key_release(&self.interface, &mut self.view, key_code, scan_code)
    }

    pub fn text_input(&mut self, utf8: &str) -> Result<bool, Error> {
        if !self.enabled {
            return Ok(false);
        }
        self.events
            .text_input(&self.interface, &self.core, &mut self.view, utf8)
    }

    pub fn mouse_move(
        &mut self,
        x: i32,
        y: i32,
        dx: i32,
        dy: i32,
        button: i32,
    ) -> Result<bool, Error> {
        if !self.enabled {
            return Ok(false);
        }
        let _ = (dx, dy, button);
        self.view.mouse_move(&self.interface, x, y)
    }

    pub fn mouse_press(&mut self, x: i32, y: i32, button: i32) -> Result<bool, Error> {
        if !self.enabled {
            return Ok(false);
        }
        self.view.mouse_press(&self.interface, x, y, button)
    }

    pub fn mouse_release(&mut self, x: i32, y: i32, button: i32) -> Result<(), Error> {
        if !self.enabled {
            return Ok(());
        }
        self.view.mouse_release(&self.interface, x, y, button)
    }

    pub fn mouse_wheel(&mut self, up: bool, value: f32) -> Result<bool, Error> {
        if !self.enabled {
            return Ok(false);
        }
        self.view.mouse_wheel(&self.interface, up, value)
    }

    fn apply(&self, effect: ChonsoleEffect) {
        match effect {
            ChonsoleEffect::Echo(text) => {
                let _ = self.interface.messages().echo(&text, "");
            }
            ChonsoleEffect::Chat(target, text) => {
                self.send_chat(target, &text);
            }
            ChonsoleEffect::EngineCommand {
                command,
                args,
                requires_cheat,
                auto_cheat,
            } => {
                self.send_engine_command(&command, &args, requires_cheat, auto_cheat);
            }
        }
    }

    fn send_chat(&self, target: ChatTarget, text: &str) {
        if text.trim().is_empty() {
            return;
        }
        let messages = self.interface.messages();
        let command = match target {
            ChatTarget::Default => format!("say {text}"),
            ChatTarget::Public => format!("say a:{text}"),
            ChatTarget::Ally => format!("say {text}"),
            ChatTarget::Spectator => format!("say s:{text}"),
        };
        if let Err(err) = messages.send_commands(&command, "") {
            log::error!("native chonsole chat failed: {err:?}");
        }
    }

    fn send_engine_command(
        &self,
        command: &str,
        args: &str,
        requires_cheat: bool,
        auto_cheat: bool,
    ) {
        let messages = self.interface.messages();
        if requires_cheat && !self.interface.game().is_cheating_enabled().unwrap_or(false) {
            if auto_cheat {
                let _ = messages.send_commands("cheat", "1");
                let _ = messages.send_commands(command, args);
                let _ = messages.send_commands("cheat", "0");
            } else {
                let _ = messages.echo("Enable cheats with /cheat or /autocheat", "");
                let _ = messages.send_commands(command, args);
            }
            return;
        }
        let _ = messages.send_commands(command, args);
    }

    fn persist_history_change(&self, before_history_len: usize) {
        let Some(store) = &self.history_store else {
            return;
        };
        let history = self.core.history();
        if history.is_empty() && before_history_len != 0 {
            store.rewrite(history);
            return;
        }
        if history.len() > before_history_len {
            store.append(&history[before_history_len..]);
        }
    }
}

struct HistoryStore {
    path: PathBuf,
}

impl HistoryStore {
    fn new(interface: &NativeInterfaceRef) -> Self {
        let path = history_path(interface);
        log::debug!("native chonsole history: {}", path.display());
        HistoryStore { path }
    }

    fn load(&self) -> Vec<String> {
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

    fn append(&self, entries: &[String]) {
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

    fn rewrite(&self, history: &[String]) {
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

#[derive(Deserialize)]
struct ExecuteRequest {
    input: String,
}

#[derive(Deserialize)]
struct SuggestRequest {
    input: String,
}

fn execute_message(sbc: &mut SBC, data: Value) {
    let request = match serde_json::from_value::<ExecuteRequest>(data) {
        Ok(request) => request,
        Err(err) => {
            log::error!("chonsole_execute: {err}");
            return;
        }
    };
    sbc.model::<ChonsoleManager>().execute(&request.input);
}

fn suggest_message(sbc: &mut SBC, data: Value) {
    let request = match serde_json::from_value::<SuggestRequest>(data) {
        Ok(request) => request,
        Err(err) => {
            log::error!("chonsole_suggest: {err}");
            return;
        }
    };
    let suggestions = sbc.model::<ChonsoleManager>().suggestions(&request.input);
    log::debug!(
        "chonsole suggestions for {:?}: {:?}",
        request.input,
        suggestions
    );
}

fn history_message(sbc: &mut SBC, _data: Value) {
    let history = sbc.model::<ChonsoleManager>().history().to_vec();
    log::debug!("chonsole history: {:?}", history);
}

fn clear_message(sbc: &mut SBC, _data: Value) {
    sbc.model::<ChonsoleManager>().clear();
}

#[cfg(test)]
mod tests {
    use std::{fs, path::PathBuf};

    use super::HistoryStore;

    fn temp_history_path(name: &str) -> PathBuf {
        std::env::temp_dir().join(format!("sbc_chonsole_{name}_{}", std::process::id()))
    }

    #[test]
    fn history_store_appends_loads_and_clears() {
        let path = temp_history_path("history_store");
        let _ = fs::remove_file(&path);
        let store = HistoryStore { path: path.clone() };

        store.append(&["/help".to_string(), "plain chat".to_string()]);
        assert_eq!(store.load(), vec!["/help", "plain chat"]);

        store.rewrite(&[]);
        assert_eq!(fs::read_to_string(&path).unwrap(), "");
        assert!(store.load().is_empty());

        let _ = fs::remove_file(path);
    }
}
