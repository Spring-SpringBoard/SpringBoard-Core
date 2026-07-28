//! Toast notifications: the native replacement for Chotify / RmlUiNotifications.
//!
//! Commands post warnings and progress here (`warn` / `progress`); the panel
//! ticks the manager each frame and renders the live toasts into
//! `#notifications-root`, a floating strip in the panel document. Timed toasts
//! expire on the wall clock, since the editor runs paused.

use std::any::Any;
use std::time::{Duration, Instant};

use spring_native::{prelude::Error, RmlDataNotificationRows, RmlNotificationRow};

use crate::sbc::command_system::model::{Model, ModelFactory};

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
    /// Post or update a plain informational toast that auto-expires. Used for
    /// reassurance ("Project saved to …") rather than warnings or progress.
    pub(crate) fn info(&mut self, name: &str, title: &str, body: &str) {
        self.upsert(name, title, body, false, None, Some(Duration::from_secs(4)));
    }

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

    /// Copies changed notification data into the panel's engine-owned model.
    /// The static RML template materialises the rows on the next context update.
    pub(crate) fn render(
        &mut self,
        notification_rows: Option<&RmlDataNotificationRows<'static>>,
    ) -> Result<(), Error> {
        let Some(notification_rows) = notification_rows else {
            return Ok(());
        };
        let values = self.rows();
        notification_rows.set(&values)
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

    fn rows(&self) -> Vec<RmlNotificationRow> {
        self.items
            .iter()
            .map(|item| RmlNotificationRow {
                title: item.title.clone(),
                body: item.body.clone(),
                warning: item.warning,
                progress: item.progress.map(|progress| progress * 100.0),
            })
            .collect()
    }
}

#[cfg(test)]
mod tests {
    use super::NotificationManager;
    use spring_native::RmlNotificationRow;

    #[test]
    fn progress_is_a_typed_percentage_not_rendered_markup() {
        let mut notifications = NotificationManager::default();
        notifications.progress("import", 0.42, "Importing heightmap...");

        assert_eq!(
            notifications.rows(),
            vec![RmlNotificationRow {
                title: "Progress".to_string(),
                body: "Importing heightmap...".to_string(),
                warning: false,
                progress: Some(42.0),
            }]
        );
    }
}
