use std::cell::RefCell;
use std::rc::Rc;

use spring_native::{
    prelude::{Error, NativeInterfaceRef},
    RmlDataModel, RmlFieldType, RmlValueRef,
};

use crate::sbc::devconsole::history_model::HistoryEntry;
use crate::sbc::devconsole::status_model::{MetricTone, StatusBarAction, StatusMetric};
use crate::sbc::rml::element_by_id;
use crate::sbc::rml::rows::{Row, Rows};

use super::UI_STYLE;

struct TextRow {
    text: String,
    muted: bool,
}

impl Row for TextRow {
    const FIELDS: &'static [(&'static str, RmlFieldType)] = &[
        ("text", RmlFieldType::String),
        ("muted", RmlFieldType::Bool),
    ];

    fn values<'a>(&'a self, out: &mut Vec<RmlValueRef<'a>>) {
        out.push(RmlValueRef::String(&self.text));
        out.push(RmlValueRef::Bool(self.muted));
    }
}

const STATUS_CONTEXT: &str = "sbc_editor_status";
const STATUS_BODY: &str = include_str!("status.rml");

type StatusBarActionQueue = Rc<RefCell<Vec<StatusBarAction>>>;

struct StatusMetricBindings {
    performance: [StatusMetricBinding; 3],
    system: [StatusMetricBinding; 4],
}

struct StatusMetricBinding {
    value: spring_native::RmlDataVariable<'static, String>,
    tones: [spring_native::RmlDataVariable<'static, bool>; 4],
}

struct StatusBindings {
    position: spring_native::RmlDataVariable<'static, String>,
    version: spring_native::RmlDataVariable<'static, String>,
    metrics: StatusMetricBindings,
    action_disabled: [spring_native::RmlDataVariable<'static, bool>; 3],
    history: Rows<TextRow>,
}

pub(crate) struct StatusBarView {
    context: u64,
    document: u64,
    position: spring_native::RmlDataVariable<'static, String>,
    version: spring_native::RmlDataVariable<'static, String>,
    metrics: StatusMetricBindings,
    action_disabled: [spring_native::RmlDataVariable<'static, bool>; 3],
    history: Rows<TextRow>,
    rendered_entries: Option<Vec<HistoryEntry>>,
    actions: StatusBarActionQueue,
}

impl StatusBarView {
    pub(crate) fn new(interface: &NativeInterfaceRef) -> Result<Option<Self>, Error> {
        let Some(context) = create_context(interface)? else {
            return Ok(None);
        };
        let bindings = bind_fields(interface, context)?;
        let Some(document) = create_document(interface, context)? else {
            let _ = interface.rml_ui().remove_context(context);
            return Ok(None);
        };
        let actions = attach_actions(interface, document)?;

        Ok(Some(StatusBarView {
            context,
            document,
            position: bindings.position,
            version: bindings.version,
            metrics: bindings.metrics,
            action_disabled: bindings.action_disabled,
            history: bindings.history,
            rendered_entries: None,
            actions,
        }))
    }

    pub(crate) fn drain_actions(&self) -> Vec<StatusBarAction> {
        self.actions.borrow_mut().drain(..).collect()
    }

    pub(crate) fn render(
        &mut self,
        interface: &NativeInterfaceRef,
        position_text: &str,
        performance: &[StatusMetric; 3],
        system: &[StatusMetric; 4],
        version_text: &str,
        entries: &[HistoryEntry],
    ) -> Result<(), Error> {
        self.position.set(position_text.to_string())?;
        self.version.set(version_text.to_string())?;
        render_metrics(&self.metrics.performance, performance)?;
        render_metrics(&self.metrics.system, system)?;

        let can_undo = entries.iter().any(|entry| !entry.undone);
        let can_redo = entries.iter().any(|entry| entry.undone);
        for (disabled, enabled) in
            self.action_disabled
                .iter()
                .zip([can_undo, can_redo, can_undo || can_redo])
        {
            disabled.set(!enabled)?;
        }
        if self.rendered_entries.as_deref() != Some(entries) {
            let rows = entries
                .iter()
                .rev()
                .take(12)
                .rev()
                .map(|entry| TextRow {
                    text: entry.caption.clone(),
                    muted: entry.undone,
                })
                .collect::<Vec<_>>();
            self.history.set(&rows)?;
            if let Some(list) = element_by_id(interface, self.document, "command-list") {
                let _ = interface.rml_ui().element_set_scroll_top(list, 1_000_000);
            }
            self.rendered_entries = Some(entries.to_vec());
        }
        Ok(())
    }

    pub(crate) fn dispose(self, interface: &NativeInterfaceRef) {
        let rml = interface.rml_ui();
        let _ = rml.document_close(self.document);
        let _ = rml.remove_context(self.context);
    }
}

fn create_context(interface: &NativeInterfaceRef) -> Result<Option<u64>, Error> {
    let (context, created) = interface.rml_ui().create_context(STATUS_CONTEXT)?;
    Ok(created.then_some(context))
}

fn bind_fields(interface: &NativeInterfaceRef, context: u64) -> Result<StatusBindings, Error> {
    let data_model = interface
        .rml_ui()
        .create_data_model(context, "editor_status")?;
    Ok(StatusBindings {
        position: data_model.bind("position", String::new())?,
        version: data_model.bind("version", String::new())?,
        metrics: StatusMetricBindings {
            performance: [
                bind_metric(&data_model, "fps")?,
                bind_metric(&data_model, "process_cpu")?,
                bind_metric(&data_model, "system_cpu")?,
            ],
            system: [
                bind_metric(&data_model, "lua_memory")?,
                bind_metric(&data_model, "vram")?,
                bind_metric(&data_model, "ram")?,
                bind_metric(&data_model, "process_memory")?,
            ],
        },
        action_disabled: [
            data_model.bind("undo_disabled", true)?,
            data_model.bind("redo_disabled", true)?,
            data_model.bind("clear_history_disabled", true)?,
        ],
        history: Rows::<TextRow>::bind(&data_model, "command_history")?,
    })
}

fn create_document(interface: &NativeInterfaceRef, context: u64) -> Result<Option<u64>, Error> {
    let rml = interface.rml_ui();
    let (document, created) = rml.context_create_document(context, "body")?;
    if !created {
        return Ok(None);
    }
    rml.document_set_title(document, "Editor status")?;
    rml.document_append_to_style_sheet(document, UI_STYLE)?;
    rml.element_set_inner_rml(document, STATUS_BODY)?;
    rml.document_show(document, spring_native::RmlDocumentShowOptions::default())?;
    Ok(Some(document))
}

fn attach_actions(
    interface: &NativeInterfaceRef,
    document: u64,
) -> Result<StatusBarActionQueue, Error> {
    let actions: StatusBarActionQueue = Rc::new(RefCell::new(Vec::new()));
    for (id, action) in [
        ("status-undo", StatusBarAction::Undo),
        ("status-redo", StatusBarAction::Redo),
        ("status-clear", StatusBarAction::ClearHistory),
    ] {
        let Some(button) = element_by_id(interface, document, id) else {
            continue;
        };
        let queue = actions.clone();
        interface
            .rml_ui()
            .element_add_event_listener(button, "click", false, move || {
                queue.borrow_mut().push(action);
            })?;
    }
    Ok(actions)
}

fn bind_metric(
    data_model: &RmlDataModel<'static>,
    name: &str,
) -> Result<StatusMetricBinding, Error> {
    Ok(StatusMetricBinding {
        value: data_model.bind(name, String::new())?,
        tones: [
            data_model.bind(format!("{name}_normal").as_str(), true)?,
            data_model.bind(format!("{name}_healthy").as_str(), false)?,
            data_model.bind(format!("{name}_warning").as_str(), false)?,
            data_model.bind(format!("{name}_critical").as_str(), false)?,
        ],
    })
}

fn render_metrics<const N: usize>(
    fields: &[StatusMetricBinding; N],
    metrics: &[StatusMetric; N],
) -> Result<(), Error> {
    for (field, metric) in fields.iter().zip(metrics) {
        field.value.set(metric.value.clone())?;
        for (tone, bound_tone) in MetricTone::ALL.iter().zip(&field.tones) {
            bound_tone.set(metric.tone == *tone)?;
        }
    }
    Ok(())
}
