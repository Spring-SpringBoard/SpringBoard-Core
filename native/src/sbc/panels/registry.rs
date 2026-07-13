use crate::sbc::panels::editor::Editor;

/// The four tabs of the right-hand panel, in display order. Mirrors the tab bar
/// of `scen_edit/view/rml/springboard_main.rml`.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub(crate) enum Tab {
    Objects,
    Map,
    Env,
    Misc,
    /// The control gallery. Off unless `SBC_DEV_PANEL=1`, so it neither ships in
    /// the editor's tab bar nor changes any other screenshot.
    Dev,
}

impl Tab {
    pub(crate) fn all() -> Vec<Tab> {
        let mut tabs = vec![Tab::Objects, Tab::Map, Tab::Env, Tab::Misc];
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
            Tab::Misc => "Misc",
            Tab::Dev => "Dev",
        }
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
