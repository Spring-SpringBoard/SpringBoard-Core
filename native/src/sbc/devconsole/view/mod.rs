mod console_view;
mod log_panel;
mod status_bar_view;
mod text;
mod toolbar_view;

pub(crate) use console_view::ConsoleView;
pub(super) use status_bar_view::StatusBarView;
pub(crate) use toolbar_view::ToggleState;

const UI_STYLE: &str = concat!(
    include_str!("../../theme/base.rcss"),
    include_str!("../../theme/controls.rcss"),
    include_str!("../../theme/scrollbars.rcss"),
    include_str!("developer_console.rcss"),
);
