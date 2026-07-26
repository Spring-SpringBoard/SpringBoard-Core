//! Object registrations at the native-module boundary.

use spring_native::prelude::NativeInterfaceRef;

use super::{event_bridge, ObjectKind, ObjectManager, SelectionManager};
use crate::sbc::command_system::model::Models;
use crate::sbc::events::{Event, EventListener, EventListenerFactory, ListenerId};
use crate::sbc::states::highlight;

/// Used when the engine will not report a feature's radius.
const DEFAULT_SELECTION_RADIUS: f32 = 40.0;

inventory::submit! { EventListenerFactory { make: |interface| Box::new(ObjectEvents { interface }) } }

/// Object-side effects that occur at the module boundary rather than inside a
/// command: Lua mirroring after a command and selected-feature drawing.
struct ObjectEvents {
    interface: NativeInterfaceRef,
}

impl EventListener for ObjectEvents {
    fn id(&self) -> ListenerId {
        ListenerId::Objects
    }

    fn handles(&self, event: Event) -> bool {
        matches!(event, Event::DrawWorldPreUnit | Event::CommandApplied)
    }

    fn draw_world_pre_unit(
        &mut self,
        models: &mut Models,
    ) -> Result<(), spring_native::prelude::Error> {
        let selected = models.get::<SelectionManager>().all();
        let boxes: Vec<(f32, f32, f32, f32)> = selected
            .into_iter()
            .filter(|(kind, _)| *kind == ObjectKind::Feature)
            .filter_map(|(kind, id)| {
                let objects = models.get::<ObjectManager>();
                let pos = objects.object_pos(kind, id)?;
                let spring_id = objects.spring_id(kind, id)?;
                let radius = self
                    .interface
                    .features()
                    .get_feature_radius(spring_id)
                    .unwrap_or(DEFAULT_SELECTION_RADIUS);
                Some((pos.x, pos.y, pos.z, radius))
            })
            .collect();
        highlight::draw_selected_features(&self.interface, &boxes);
        Ok(())
    }

    fn command_applied(&mut self, models: &mut Models) {
        event_bridge::emit(
            &self.interface,
            models.get::<ObjectManager>().drain_events(),
        );
    }
}
