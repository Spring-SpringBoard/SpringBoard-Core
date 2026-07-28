use spring_native::prelude::{Error, NativeInterfaceRef};

use super::{
    element_by_id, rml, DevConsoleView, HistoryCommand, StatusAction, StatusMetricBindings,
    STATUS_BODY, STATUS_CONTEXT, UI_STYLE,
};
use crate::sbc::devconsole::status::{MetricTone, StatusMetric};
use spring_native::RmlTextRow;

impl DevConsoleView {
    pub(crate) fn render_status(
        &mut self,
        interface: &NativeInterfaceRef,
        position: &str,
        performance: &[StatusMetric; 3],
        system: &[StatusMetric; 4],
        version: &str,
        commands: &[HistoryCommand],
    ) -> Result<(), Error> {
        let Some(doc) = self.status_document else {
            return Ok(());
        };
        if let Some(field) = &self.status_position {
            field.set(position.to_string())?;
        }
        if let Some(field) = &self.status_version {
            field.set(version.to_string())?;
        }
        if let Some(fields) = &self.status_metrics {
            render_metrics(
                interface,
                doc,
                "status-performance",
                &fields.performance,
                performance,
            )?;
            render_metrics(interface, doc, "status-system", &fields.system, system)?;
        }
        let can_undo = commands.iter().any(|command| !command.undone);
        let can_redo = commands.iter().any(|command| command.undone);
        for (id, enabled) in [
            ("status-undo", can_undo),
            ("status-redo", can_redo),
            ("status-clear", can_undo || can_redo),
        ] {
            if let Some(button) = element_by_id(interface, doc, id) {
                interface
                    .rml_ui()
                    .element_set_class(button, "disabled", !enabled)?;
            }
        }
        if self.rendered_command_log.as_deref() != Some(commands) {
            if let Some(history) = &self.status_history {
                let rows = commands
                    .iter()
                    .rev()
                    .take(12)
                    .rev()
                    .map(|command| RmlTextRow {
                        text: command.caption.clone(),
                        muted: command.undone,
                    })
                    .collect::<Vec<_>>();
                history.set(&rows)?;
                self.status_history_muted = rows.iter().map(|row| row.muted).collect();
            }
            if let Some(list) = element_by_id(interface, doc, "command-list") {
                let _ = interface.rml_ui().element_set_scroll_top(list, 1_000_000);
            }
            self.rendered_command_log = Some(commands.to_vec());
        }
        Ok(())
    }

    pub(super) fn ensure_status(&mut self, interface: &NativeInterfaceRef) -> Result<(), Error> {
        if let Some(context) = self.status_context {
            if rml::context_is_alive(interface, STATUS_CONTEXT, Some(context)) {
                return Ok(());
            }
            self.status_context = None;
            self.status_document = None;
            self.status_position = None;
            self.status_version = None;
            self.status_metrics = None;
            self.status_history = None;
            self.status_history_muted.clear();
            self.rendered_command_log = None;
        }
        let rml = interface.rml_ui();
        let (context, created) = rml.create_context(STATUS_CONTEXT)?;
        if !created {
            return Ok(());
        }
        let geometry = interface.display().get_view_geometry()?;
        let _ = rml.context_set_dimensions(context, geometry.viewSizeX, geometry.viewSizeY);

        let data_model = rml.create_data_model(context, "editor_status")?;
        self.status_position = Some(data_model.bind("position", String::new())?);
        self.status_version = Some(data_model.bind("version", String::new())?);
        self.status_metrics = Some(StatusMetricBindings {
            performance: [
                data_model.bind("fps", String::new())?,
                data_model.bind("process_cpu", String::new())?,
                data_model.bind("system_cpu", String::new())?,
            ],
            system: [
                data_model.bind("lua_memory", String::new())?,
                data_model.bind("vram", String::new())?,
                data_model.bind("ram", String::new())?,
                data_model.bind("process_memory", String::new())?,
            ],
        });
        self.status_history = Some(data_model.bind_text_rows("command_history")?);

        let (document, created) = rml.context_create_document(context, "body")?;
        if !created {
            let _ = rml.remove_context(context);
            self.status_position = None;
            self.status_version = None;
            self.status_metrics = None;
            self.status_history = None;
            self.status_history_muted.clear();
            return Ok(());
        }
        rml.document_set_title(document, "Editor status")?;
        rml.document_append_to_style_sheet(document, UI_STYLE)?;
        rml.element_set_inner_rml(document, STATUS_BODY)?;
        rml.document_show(document, None, None)?;
        self.status_context = Some(context);
        self.status_document = Some(document);
        self.rendered_command_log = None;
        self.bind_status_actions(interface)
    }

    fn bind_status_actions(&self, interface: &NativeInterfaceRef) -> Result<(), Error> {
        let Some(doc) = self.status_document else {
            return Ok(());
        };
        for (id, action) in [
            ("status-undo", StatusAction::Undo),
            ("status-redo", StatusAction::Redo),
            ("status-clear", StatusAction::ClearHistory),
        ] {
            let Some(button) = element_by_id(interface, doc, id) else {
                continue;
            };
            let queue = self.status_actions.clone();
            interface
                .rml_ui()
                .element_add_event_listener(button, "click", false, move || {
                    queue.borrow_mut().push(action);
                })?;
        }
        Ok(())
    }
}

fn render_metrics<const N: usize>(
    interface: &NativeInterfaceRef,
    document: u64,
    group_id: &str,
    fields: &[spring_native::RmlDataVariable<'static, String>; N],
    metrics: &[StatusMetric; N],
) -> Result<(), Error> {
    for (index, (field, metric)) in fields.iter().zip(metrics).enumerate() {
        field.set(metric.value.clone())?;
        let Some(element) = element_by_id(interface, document, &format!("{group_id}-{index}"))
        else {
            continue;
        };
        for tone in MetricTone::ALL {
            interface
                .rml_ui()
                .element_set_class(element, tone.class(), metric.tone == tone)?;
        }
    }
    Ok(())
}
