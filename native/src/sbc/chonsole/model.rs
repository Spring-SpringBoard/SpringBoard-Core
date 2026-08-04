use std::any::Any;

use spring_native::prelude::{Error, NativeInterfaceRef};

use super::commands::{CatalogRefresher, ChonsoleCore, CommandExecutor, CommandRegistry};
use super::framework::{ChonsoleResponse, ChonsoleSuggestion, HistoryStore};
use super::ui::{ChonsoleController, UiKeyOutcome};
use crate::sbc::command_system::model::{Model, ModelFactory};
use crate::sbc::keys::KeyMods;
use crate::sbc::port_flags::{self, PortImpl};

inventory::submit! { ModelFactory { make: |iface| Box::new(ChonsoleManager::new(iface)) } }

pub struct ChonsoleManager {
    interface: NativeInterfaceRef,
    enabled: bool,
    core: ChonsoleCore,
    ui: ChonsoleController,
    history_store: Option<HistoryStore>,
    command_registry: CommandRegistry,
    executor: CommandExecutor,
    catalogs: CatalogRefresher,
}

impl Model for ChonsoleManager {
    fn as_any_mut(&mut self) -> &mut dyn Any {
        self
    }
}

impl Drop for ChonsoleManager {
    fn drop(&mut self) {
        if self.enabled {
            self.ui.dispose(&self.interface);
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
        let command_registry = CommandRegistry::default();
        let mut core = ChonsoleCore::with_history(history);
        command_registry.install(&mut core);
        ChonsoleManager {
            interface,
            enabled,
            core,
            ui: ChonsoleController::default(),
            history_store,
            command_registry,
            executor: CommandExecutor::default(),
            catalogs: CatalogRefresher::default(),
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
        let previous_history = self.core.history().to_vec();
        let action = self.command_registry.resolve(input);
        let (response, effects) = self.core.execute(input, action);
        self.persist_history_change(&previous_history);
        for effect in effects {
            self.executor.apply(&self.interface, effect);
        }
        self.ui.apply_response(&response, &self.core);
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

    pub fn visible(&self) -> bool {
        self.enabled && self.ui.visible()
    }

    pub fn clear(&mut self) {
        if !self.enabled {
            return;
        }
        self.core.clear();
        if let Some(store) = &self.history_store {
            store.rewrite(self.core.history());
        }
        self.ui.clear();
    }

    pub fn update(&mut self) -> Result<(), Error> {
        if !self.enabled {
            return Ok(());
        }
        self.catalogs.refresh(&self.interface, &mut self.core);
        self.ui.update(&self.interface, &self.core)
    }

    pub fn draw_screen(&mut self) -> Result<(), Error> {
        if !self.enabled {
            return Ok(());
        }
        self.executor.export_pending_texture(&self.interface);
        self.ui.draw_screen(&self.interface)
    }

    pub fn key_press(
        &mut self,
        key_code: i32,
        scan_code: i32,
        is_repeat: bool,
        mods: KeyMods,
    ) -> Result<bool, Error> {
        if !self.enabled {
            return Ok(false);
        }
        match self.ui.key_press(
            &self.interface,
            &self.core,
            key_code,
            scan_code,
            is_repeat,
            mods,
        )? {
            UiKeyOutcome::Unhandled => Ok(false),
            UiKeyOutcome::Handled => Ok(true),
            UiKeyOutcome::Execute(input) => {
                self.execute(&input);
                self.ui.hide(&self.interface)?;
                Ok(true)
            }
        }
    }

    pub fn text_key(&mut self, key_code: i32, mods: KeyMods) -> Result<bool, Error> {
        if !self.enabled {
            return Ok(false);
        }
        self.ui
            .text_key(&self.interface, &self.core, key_code, mods)
    }

    pub fn key_release(&mut self, key_code: i32, scan_code: i32) -> Result<bool, Error> {
        if !self.enabled {
            return Ok(false);
        }
        self.ui.key_release(&self.interface, key_code, scan_code)
    }

    pub fn text_input(&mut self, utf8: &str) -> Result<bool, Error> {
        if !self.enabled {
            return Ok(false);
        }
        self.ui.text_input(&self.interface, &self.core, utf8)
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
        let y = self.rml_y(y);
        self.ui.mouse_move(&self.interface, x, y)
    }

    pub fn mouse_press(&mut self, x: i32, y: i32, button: i32) -> Result<bool, Error> {
        if !self.enabled {
            return Ok(false);
        }
        let y = self.rml_y(y);
        self.ui.mouse_press(&self.interface, x, y, button)
    }

    pub fn mouse_release(&mut self, x: i32, y: i32, button: i32) -> Result<(), Error> {
        if !self.enabled {
            return Ok(());
        }
        let y = self.rml_y(y);
        self.ui.mouse_release(&self.interface, x, y, button)
    }

    pub fn mouse_wheel(&mut self, up: bool, value: f32) -> Result<bool, Error> {
        if !self.enabled {
            return Ok(false);
        }
        self.ui.mouse_wheel(&self.interface, up, value)
    }

    /// Mouse callbacks report the engine's bottom-origin y; the view hit tests
    /// against RmlUi's top-origin layout.
    fn rml_y(&self, y: i32) -> i32 {
        match self.interface.display().get_view_geometry() {
            Ok(geometry) => geometry.viewSizeY - 1 - y,
            Err(_) => y,
        }
    }

    fn persist_history_change(&self, previous_history: &[String]) {
        let Some(store) = &self.history_store else {
            return;
        };
        let history = self.core.history();
        // Rewriting a maximum of 100 short entries keeps the on-disk history
        // exactly aligned with the capped in-memory list. Appending based only
        // on length missed the important case where a new entry evicts the
        // oldest one, because the length remains unchanged.
        if history != previous_history {
            store.rewrite(history);
        }
    }
}
