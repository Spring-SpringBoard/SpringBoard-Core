use crate::sbc::command_system::model::Models;
use crate::sbc::panels::editor::Editor;

/// The tabs of the right-hand panel, in display order. The first four mirror the
/// tab bar of `scen_edit/view/rml/springboard_main.rml` (the Lua shell).
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub(crate) enum Tab {
    Objects,
    Map,
    Env,
    /// The game's effect editors. Shown only while the running game's renderer
    /// offers them, so other games see no empty tab.
    Effects,
    Misc,
    /// The control gallery. Off unless `SBC_DEV_PANEL=1`, so it neither ships in
    /// the editor's tab bar nor changes any other screenshot.
    Dev,
}

impl Tab {
    pub(crate) fn all() -> Vec<Tab> {
        let mut tabs = vec![Tab::Objects, Tab::Map, Tab::Env, Tab::Effects, Tab::Misc];
        if dev_panel() {
            tabs.push(Tab::Dev);
        }
        tabs
    }

    pub(crate) fn as_str(self) -> &'static str {
        match self {
            Tab::Objects => "Objects",
            Tab::Map => "Map",
            Tab::Env => "Env",
            Tab::Effects => "Effects",
            Tab::Misc => "Misc",
            Tab::Dev => "Dev",
        }
    }

    /// Whether the tab bar shows the tab now. Every tab but Effects always is.
    pub(crate) fn shown(self, models: &mut Models) -> bool {
        match self {
            Tab::Effects => crate::sbc::render_lab::offers_effects(models),
            _ => true,
        }
    }

    /// The tabs the tab bar shows now, in display order.
    pub(crate) fn visible(models: &mut Models) -> Vec<Tab> {
        Tab::all()
            .into_iter()
            .filter(|tab| tab.shown(models))
            .collect()
    }
}

pub(crate) fn dev_panel() -> bool {
    static ON: std::sync::OnceLock<bool> = std::sync::OnceLock::new();
    *ON.get_or_init(|| matches!(std::env::var("SBC_DEV_PANEL").as_deref(), Ok("1")))
}

/// One editor view, registered from its own module. Adding a view means adding
/// a file that submits a spec — nothing else in the shell changes, which is what
/// lets views be merged one at a time.
pub(crate) struct EditorSpec {
    pub name: &'static str,
    pub tab: Tab,
    /// Position within the tab's button strip.
    pub order: u32,
    pub caption: &'static str,
    pub tooltip: &'static str,
    /// VFS path of the button icon, e.g. `LuaUI/images/scenedit/sun.png`.
    pub image: &'static str,
    pub make: fn() -> Box<dyn Editor>,
}

inventory::collect!(EditorSpec);

/// Registered editors for a tab, ordered by `order` then `caption`, exactly as
/// `CreateTabsFromEditorRegistry` orders them in Lua.
pub(crate) fn editors_for(tab: Tab) -> Vec<&'static EditorSpec> {
    let mut specs: Vec<&EditorSpec> = inventory::iter::<EditorSpec>
        .into_iter()
        .filter(|spec| spec.tab == tab)
        .collect();
    specs.sort_by(|a, b| a.order.cmp(&b.order).then(a.caption.cmp(b.caption)));
    specs
}

pub(crate) fn editor_by_name(name: &str) -> Option<&'static EditorSpec> {
    inventory::iter::<EditorSpec>
        .into_iter()
        .find(|spec| spec.name == name)
}
