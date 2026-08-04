use spring_native::{
    prelude::{Error, NativeInterfaceRef},
    RmlDataModel,
};

use super::{
    element_by_id, rml, DevConsoleView, HistoryCommand, StatusAction, StatusMetricBinding,
    StatusMetricBindings, STATUS_BODY, STATUS_CONTEXT, UI_STYLE,
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
            render_metrics(&fields.performance, performance)?;
            render_metrics(&fields.system, system)?;
        }
        let can_undo = commands.iter().any(|command| !command.undone);
        let can_redo = commands.iter().any(|command| command.undone);
        for (disabled, enabled) in
            self.status_action_disabled
                .iter()
                .zip([can_undo, can_redo, can_undo || can_redo])
        {
            if let Some(disabled) = disabled {
                disabled.set(!enabled)?;
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
                        visible: true,
                    })
                    .collect::<Vec<_>>();
                history.set(&rows)?;
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
            self.status_action_disabled = [None; 3];
            self.status_history = None;
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
        });
        self.status_action_disabled = [
            Some(data_model.bind("undo_disabled", true)?),
            Some(data_model.bind("redo_disabled", true)?),
            Some(data_model.bind("clear_history_disabled", true)?),
        ];
        self.status_history = Some(data_model.bind_text_rows("command_history")?);

        let (document, created) = rml.context_create_document(context, "body")?;
        if !created {
            let _ = rml.remove_context(context);
            self.status_position = None;
            self.status_version = None;
            self.status_metrics = None;
            self.status_action_disabled = [None; 3];
            self.status_history = None;
            return Ok(());
        }
        rml.document_set_title(document, "Editor status")?;
        rml.document_append_to_style_sheet(document, UI_STYLE)?;
        rml.element_set_inner_rml(document, STATUS_BODY)?;
        rml.document_show(document, spring_native::RmlDocumentShowOptions::default())?;
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
