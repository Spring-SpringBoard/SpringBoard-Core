//! The one place that defines cross-feature event and lifecycle ordering.

/// A native-module callin.
#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub(crate) enum Event {
    DrawScreen,
    DrawScreenPost,
    DrawWorld,
    DrawWorldPreUnit,
    KeyPress,
    KeyRelease,
    TextInput,
    MouseMove,
    MousePress,
    MouseRelease,
    MouseWheel,
    ConsoleLine,
    CommandRecorded,
    CommandHistoryChanged,
    CommandApplied,
}

/// Stable identity for each registered listener. It is intentionally separate
/// from implementation type: all cross-feature ordering belongs here.
#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub(crate) enum ListenerId {
    ChonsoleText,
    Chonsole,
    Panel,
    DevConsoleText,
    DevConsole,
    State,
    Screenshot,
    Objects,
}

impl ListenerId {
    /// Unlisted combinations are neutral (0), not first: negative values run
    /// before them and positive values after.
    pub(super) fn event_priority(self, event: Event) -> i16 {
        match (self, event) {
            (Self::Screenshot, Event::DrawScreen | Event::DrawScreenPost) => -20,
            (Self::State, Event::DrawScreen) => -10,
            (Self::Chonsole, Event::DrawScreen) => 0,
            (Self::Panel, Event::DrawScreen) => 10,
            (Self::ChonsoleText, Event::KeyPress) => -30,
            (Self::DevConsoleText, Event::KeyPress) => -20,
            (Self::Panel, Event::KeyPress) => 0,
            (Self::DevConsole, Event::KeyPress) => 10,
            (Self::Chonsole, Event::KeyPress) => 20,
            (Self::State, Event::KeyPress) => 30,
            (Self::Panel, Event::KeyRelease | Event::TextInput) => -10,
            (Self::Chonsole, Event::KeyRelease | Event::TextInput) => 10,
            (
                Self::Chonsole,
                Event::MouseMove | Event::MousePress | Event::MouseRelease | Event::MouseWheel,
            ) => -10,
            (
                Self::Panel,
                Event::MouseMove | Event::MousePress | Event::MouseRelease | Event::MouseWheel,
            ) => 0,
            (
                Self::State,
                Event::MouseMove | Event::MousePress | Event::MouseRelease | Event::MouseWheel,
            ) => 10,
            _ => 0,
        }
    }

    pub(super) fn update_slot(self) -> Option<UpdateSlot> {
        match self {
            Self::Chonsole => Some(UpdateSlot::ChonsoleUpdate),
            Self::Panel => Some(UpdateSlot::PanelUpdate),
            Self::DevConsole => Some(UpdateSlot::DevConsoleUpdate),
            Self::State => Some(UpdateSlot::StateUpdate),
            _ => None,
        }
    }

    pub(super) fn command_drain_slot(self) -> Option<UpdateSlot> {
        match self {
            Self::DevConsole => Some(UpdateSlot::DevConsoleCommands),
            Self::Panel => Some(UpdateSlot::PanelCommands),
            Self::State => Some(UpdateSlot::StateCommands),
            _ => None,
        }
    }
}

/// The complete per-tick lifecycle order. Leave gaps for future operations.
#[derive(Clone, Copy, Debug, Eq, Ord, PartialEq, PartialOrd)]
#[repr(u16)]
pub(crate) enum UpdateSlot {
    ChonsoleUpdate = 100,
    PanelUpdate = 200,
    DevConsoleUpdate = 300,
    DevConsoleCommands = 350,
    StateUpdate = 400,
    PanelCommands = 500,
    StateCommands = 600,
}
