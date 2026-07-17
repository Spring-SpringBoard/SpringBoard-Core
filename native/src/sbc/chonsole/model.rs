use std::any::Any;

use spring_native::prelude::{Error, NativeInterfaceRef};

use super::catalog::CatalogRefresher;
use super::commands::CommandExecutor;
use super::core::ChonsoleCore;
use super::events::{ChonsoleEvents, KeyOutcome};
use super::history::HistoryStore;
use super::types::{ChonsoleResponse, ChonsoleSuggestion};
use super::view::ChonsoleView;
use crate::sbc::command_system::model::{Model, ModelFactory};
use crate::sbc::port_flags::{self, PortImpl};

inventory::submit! { ModelFactory { make: |iface| Box::new(ChonsoleManager::new(iface)) } }

pub struct ChonsoleManager {
    interface: NativeInterfaceRef,
    enabled: bool,
    core: ChonsoleCore,
    view: ChonsoleView,
    events: ChonsoleEvents,
    history_store: Option<HistoryStore>,
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
        let (response, effects) = self.core.execute(input);
        self.persist_history_change(&previous_history);
        for effect in effects {
            self.executor.apply(&self.interface, effect);
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

    pub fn visible(&self) -> bool {
        self.enabled && self.view.visible()
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
        self.catalogs.refresh(&self.interface, &mut self.core);
        self.view.ensure(&self.interface)?;
        if self.view.process_suggestion_clicks(&self.core) {
            self.view.refresh(&self.interface, &self.core)?;
        }
        self.view.process_suggestion_hovers(&self.interface);
        self.view.update(&self.interface)
    }

    pub fn draw_screen(&mut self) -> Result<(), Error> {
        if !self.enabled {
            return Ok(());
        }
        self.executor.export_pending_texture(&self.interface);
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
