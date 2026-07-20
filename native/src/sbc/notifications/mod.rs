//! Toast notifications: the native replacement for Chotify / RmlUiNotifications.
//!
//! Commands post warnings and progress here (`warn` / `progress`); the panel
//! ticks the manager each frame and renders the live toasts into
//! `#notifications-root`, a floating strip in the panel document. Timed toasts
//! expire on the wall clock, since the editor runs paused.

use std::any::Any;
use std::time::{Duration, Instant};

use spring_native::prelude::{Error, NativeInterfaceRef};

use crate::sbc::command_system::model::{Model, ModelFactory};
use crate::sbc::rml::{element_by_id, escape_rml};

inventory::submit! { ModelFactory { make: |_iface| Box::new(NotificationManager::default()) } }

struct Notification {
    /// Dedup key: posting the same name updates the existing toast in place.
    name: String,
    title: String,
    body: String,
    warning: bool,
    progress: Option<f32>,
    expires: Option<Instant>,
}

#[derive(Default)]
pub(crate) struct NotificationManager {
    items: Vec<Notification>,
    dirty: bool,
}

impl Model for NotificationManager {
    fn as_any_mut(&mut self) -> &mut dyn Any {
        self
    }
}

impl NotificationManager {
    /// Post or update a warning toast; it auto-expires after a few seconds.
    pub(crate) fn warn(&mut self, name: &str, body: &str) {
        self.upsert(
            name,
            "Warning",
            body,
            true,
            None,
            Some(Duration::from_secs(4)),
        );
    }

    /// Post or update a progress toast (0.0..1.0). At >= 1.0 the progress toast
    /// is replaced by a brief "Finished" one, mirroring `SB.ActionProgress`.
    pub(crate) fn progress(&mut self, name: &str, value: f32, body: &str) {
        if value >= 1.0 {
            self.remove(name);
            self.upsert(
                &format!("{name}-done"),
                "Finished",
                body,
                false,
                None,
                Some(Duration::from_secs(3)),
            );
        } else {
            self.upsert(
                name,
                "Progress",
                body,
                false,
                Some(value.clamp(0.0, 1.0)),
                None,
            );
        }
    }

    fn upsert(
        &mut self,
        name: &str,
        title: &str,
        body: &str,
        warning: bool,
        progress: Option<f32>,
        ttl: Option<Duration>,
    ) {
        let expires = ttl.map(|d| Instant::now() + d);
        if let Some(existing) = self.items.iter_mut().find(|item| item.name == name) {
            existing.title = title.to_string();
            existing.body = body.to_string();
            existing.warning = warning;
            existing.progress = progress;
            existing.expires = expires;
        } else {
            self.items.push(Notification {
                name: name.to_string(),
                title: title.to_string(),
                body: body.to_string(),
                warning,
                progress,
                expires,
            });
        }
        self.dirty = true;
    }

    fn remove(&mut self, name: &str) {
        let before = self.items.len();
        self.items.retain(|item| item.name != name);
        if self.items.len() != before {
            self.dirty = true;
        }
    }

    /// Expire timed-out toasts and report whether the toast strip changed since
    /// the last render (posts, updates, and expiries all count).
    pub(crate) fn tick(&mut self) -> bool {
        let now = Instant::now();
        let before = self.items.len();
        self.items
            .retain(|item| item.expires.is_none_or(|expiry| expiry > now));
        if self.items.len() != before {
            self.dirty = true;
        }
        std::mem::take(&mut self.dirty)
    }

    pub(crate) fn render(
        &self,
        interface: &NativeInterfaceRef,
        document: u64,
    ) -> Result<(), Error> {
        let Some(root) = element_by_id(interface, document, "notifications-root") else {
            return Ok(());
        };
        let mut html = String::new();
        for item in &self.items {
            let warning = if item.warning { " warning" } else { "" };
            html.push_str(&format!(
                concat!(
                    r#"<div class="notification">"#,
                    r#"<div class="notification-title{warning}">{title}</div>"#,
                    r#"<div class="notification-body">{body}</div>"#,
                ),
                warning = warning,
                title = escape_rml(&item.title),
                body = escape_rml(&item.body),
            ));
            if let Some(progress) = item.progress {
                html.push_str(&format!(
                    concat!(
                        r#"<div class="notification-progress">"#,
                        r#"<div class="notification-progress-fill" style="width: {pct}%;"></div></div>"#,
                    ),
                    pct = (progress * 100.0).round() as i32,
                ));
            }
            html.push_str("</div>");
        }
        interface.rml_ui().element_set_inner_rml(root, &html)?;
        Ok(())
    }
}
