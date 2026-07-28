use spring_native::{
    prelude::{Error, NativeInterfaceRef},
    RmlColor, RmlDataModel, RmlDataVariable,
};

use crate::sbc::panels::field::{
    element_by_id, escape_rml, on_change, on_pointer, ChangeQueue, Field, FieldValue,
    InteractionQueue,
};

const CHANNEL_STEP: f32 = 0.005; // 1/200 per pixel, matches original

/// Color field with an expandable RGB editor. Shows a color swatch; click to
/// expand inline R/G/B drag controls + hex input. Drag channels to adjust.
pub(crate) struct ColorField {
    name: String,
    title: String,
    tooltip: Option<String>,
    value: [f32; 4],
    channels: [ChannelElems; 3],
    expanded: bool,
    drag_channel: Option<usize>, // 0=R, 1=G, 2=B
    swatch_color: Option<RmlDataVariable<'static, RmlColor>>,
    channel_values: [Option<RmlDataVariable<'static, String>>; 3],
    channel_editing: [Option<RmlDataVariable<'static, bool>>; 3],
    hex_value: Option<RmlDataVariable<'static, String>>,
    expanded_value: Option<RmlDataVariable<'static, bool>>,
}

struct ChannelElems {
    edit: Option<u64>,
}

impl ChannelElems {
    const fn none() -> Self {
        ChannelElems { edit: None }
    }
}

impl ColorField {
    pub(crate) fn new(name: impl Into<String>, title: impl Into<String>) -> Self {
        ColorField {
            name: name.into(),
            title: title.into(),
            value: [1.0, 1.0, 1.0, 1.0],
            channels: [
                ChannelElems::none(),
                ChannelElems::none(),
                ChannelElems::none(),
            ],
            expanded: false,
            drag_channel: None,
            swatch_color: None,
            channel_values: [None, None, None],
            channel_editing: [None, None, None],
            hex_value: None,
            expanded_value: None,
            tooltip: None,
        }
    }

    pub(crate) fn with_tooltip(mut self, tooltip: &str) -> Self {
        self.tooltip = Some(tooltip.to_string());
        self
    }

    #[allow(dead_code)]
    pub(crate) fn get(&self) -> [f32; 4] {
        self.value
    }

    // ── Conversions ──

    fn to_rml_color(c: [f32; 4]) -> RmlColor {
        RmlColor {
            red: (c[0].clamp(0.0, 1.0) * 255.0).round() as u8,
            green: (c[1].clamp(0.0, 1.0) * 255.0).round() as u8,
            blue: (c[2].clamp(0.0, 1.0) * 255.0).round() as u8,
            alpha: (c[3].clamp(0.0, 1.0) * 255.0).round() as u8,
        }
    }

    fn to_hex(c: [f32; 4]) -> String {
        format!(
            "#{:02X}{:02X}{:02X}",
            (c[0].clamp(0.0, 1.0) * 255.0) as u8,
            (c[1].clamp(0.0, 1.0) * 255.0) as u8,
            (c[2].clamp(0.0, 1.0) * 255.0) as u8,
        )
    }

    fn parse_hex_or_csv(text: &str) -> [f32; 4] {
        let t = text.trim().trim_start_matches('#');
        if t.len() == 6 {
            let byte = |i: usize| {
                u8::from_str_radix(t.get(i..i + 2).unwrap_or("00"), 16).unwrap_or(0) as f32 / 255.0
            };
            [byte(0), byte(2), byte(4), 1.0]
        } else if t.contains(',') {
            let p: Vec<f32> = t
                .split(',')
                .map(|s| s.trim().parse().unwrap_or(0.0))
                .collect();
            [
                p.first().copied().unwrap_or(0.0),
                p.get(1).copied().unwrap_or(0.0),
                p.get(2).copied().unwrap_or(0.0),
                1.0,
            ]
        } else {
            [0.0, 0.0, 0.0, 1.0]
        }
    }

    // ── Typed presentation bindings ──

    fn binding_name(&self, suffix: &str) -> String {
        let name = self
            .name
            .chars()
            .map(|character| {
                if character.is_ascii_alphanumeric() {
                    character
                } else {
                    '_'
                }
            })
            .collect::<String>();
        format!("field_{name}_{suffix}")
    }

    fn sync_swatch(&self) {
        let color = self
            .swatch_color
            .as_ref()
            .expect("color field is bound before it receives input");
        let _ = color.set(Self::to_rml_color(self.value));
    }

    fn sync_channels(&self) {
        for i in 0..self.channels.len() {
            let val = format!("{:.2}", self.value[i]);
            if let Some(value) = &self.channel_values[i] {
                let _ = value.set(val);
            }
        }
    }

    fn sync_hex(&self) {
        if let Some(value) = &self.hex_value {
            let _ = value.set(Self::to_hex(self.value));
        }
    }

    fn set_expanded(&mut self, on: bool) {
        self.expanded = on;
        if let Some(expanded) = &self.expanded_value {
            let _ = expanded.set(on);
        }
    }

    fn read_channel_input(&mut self, idx: usize) {
        if let Some(value) = &self.channel_values[idx] {
            if let Ok(text) = value.get() {
                self.value[idx] = text.parse().unwrap_or(self.value[idx]).clamp(0.0, 1.0);
            }
        }
        if let Some(editing) = &self.channel_editing[idx] {
            let _ = editing.set(false);
        }
        self.sync_swatch();
        self.sync_channels();
    }

    fn read_hex_input(&mut self) {
        if let Some(value) = &self.hex_value {
            if let Ok(text) = value.get() {
                self.value = Self::parse_hex_or_csv(&text);
            }
        }
        self.sync_swatch();
        self.sync_channels();
        self.sync_hex();
    }
}

impl Field for ColorField {
    fn name(&self) -> &str {
        &self.name
    }

    fn tooltip(&self) -> Option<&str> {
        self.tooltip.as_deref()
    }

    fn prepare_data_model(&mut self, model: &RmlDataModel<'static>) -> Result<(), Error> {
        self.swatch_color =
            Some(model.bind(&self.binding_name("swatch"), Self::to_rml_color(self.value))?);
        for index in 0..3 {
            self.channel_values[index] = Some(model.bind(
                &self.binding_name(&format!("channel_{index}")),
                format!("{:.2}", self.value[index]),
            )?);
            self.channel_editing[index] = Some(model.bind(
                &self.binding_name(&format!("channel_{index}_editing")),
                false,
            )?);
        }
        self.hex_value = Some(model.bind(&self.binding_name("hex"), Self::to_hex(self.value))?);
        self.expanded_value = Some(model.bind(&self.binding_name("expanded"), false)?);
        Ok(())
    }

    fn generate_rml(&self) -> String {
        let n = &self.name;
        let swatch = self.binding_name("swatch");
        let expanded = self.binding_name("expanded");
        let hex = self.binding_name("hex");
        let channels: String = ['r', 'g', 'b']
            .iter()
            .enumerate()
            .map(|(i, &ch)| {
                let value = self.binding_name(&format!("channel_{i}"));
                let editing = self.binding_name(&format!("channel_{i}_editing"));
                format!(
                    r#"<div class="field-inline"><span class="field-label channel-label {ch}">{ch}</span>"#
                ) + &format!(
                    r#"<button id="field-{n}-{ch}-display" class="field-composite-button field-numeric-button color-channel" data-class-hidden="{editing}">{{{{ {value} }}}}</button>"#,
                ) + &format!(
                    r#"<input type="text" id="field-{n}-{ch}-edit" class="field-input field-numeric-input color-channel" data-class-hidden="!{editing}" data-value="{value}"/></div>"#,
                )
            })
            .collect();

        // Same shape as RmlUiColorField in scen_edit/view/rmlui_fields.lua: a
        // composite button carrying the title and the swatch. The inline RGB
        // editor below it is native-only (Lua opens a picker dialog instead).
        r#"<div class="field-row"><div class="color-field">"#.to_string()
            + &format!(
                r#"<button id="field-{n}-swatch" class="field-composite-button field-color-button"><span class="field-button-title">{title}:</span><span class="field-swatch" data-style-background-color="{swatch}"></span></button>"#,
                title = escape_rml(self.title.trim_end_matches(':')),
            )
            + &format!(
                r#"<div id="field-{n}-editor" class="color-editor" data-class-hidden="!{expanded}">"#,
            )
            + &format!(
                r#"<input type="text" id="field-{n}-hex" class="field-input color-hex" data-value="{hex}"/>"#,
            )
            + &format!(r#"<div class="color-channels">{channels}</div>"#)
            + "</div></div></div>"
    }

    fn bind(
        &mut self,
        interface: &NativeInterfaceRef,
        document: u64,
        changes: &ChangeQueue,
        interactions: &InteractionQueue,
    ) -> Result<(), Error> {
        let n = &self.name;
        for (i, ch) in ['r', 'g', 'b'].iter().enumerate() {
            self.channels[i].edit =
                element_by_id(interface, document, &format!("field-{n}-{ch}-edit"));
        }

        // Swatch: click to toggle expand
        if let Some(e) = element_by_id(interface, document, &format!("field-{n}-swatch")) {
            on_pointer(interface, e, self.name.clone(), interactions)?;
        }
        // Hex input: change → read
        if let Some(e) = element_by_id(interface, document, &format!("field-{n}-hex")) {
            on_change(interface, e, format!("{}-hex", self.name), changes)?;
        }
        // Each channel: drag + edit
        for (i, ch) in ['r', 'g', 'b'].iter().enumerate() {
            let sub_name = format!("{}-{ch}", self.name);
            if let Some(e) = element_by_id(interface, document, &format!("field-{n}-{ch}-display"))
            {
                on_pointer(interface, e, sub_name.clone(), interactions)?;
            }
            if let Some(e) = self.channels[i].edit {
                on_change(interface, e, sub_name, changes)?;
            }
        }
        Ok(())
    }

    fn read_from_dom(&mut self, _interface: &NativeInterfaceRef) -> Result<FieldValue, Error> {
        Ok(FieldValue::Color(self.value))
    }

    fn write_to_dom(&self, _interface: &NativeInterfaceRef) -> Result<(), Error> {
        self.sync_swatch();
        self.sync_channels();
        self.sync_hex();
        Ok(())
    }

    fn set_value(&mut self, value: &FieldValue) {
        if let FieldValue::Color(v) = value {
            self.value = *v;
        }
    }

    fn value(&self) -> FieldValue {
        FieldValue::Color(self.value)
    }

    fn drag(&mut self, dx: f32, _interface: &NativeInterfaceRef) {
        let idx = self.drag_channel.unwrap_or(0);
        self.value[idx] = (self.value[idx] + dx * CHANNEL_STEP).clamp(0.0, 1.0);
        self.sync_swatch();
        self.sync_channels();
    }

    fn drag_end(&mut self, _interface: &NativeInterfaceRef) -> Option<FieldValue> {
        self.drag_channel = None;
        Some(FieldValue::Color(self.value))
    }

    fn prepare_drag(&mut self, context: &str) {
        self.drag_channel = match context {
            "r" => Some(0),
            "g" => Some(1),
            "b" => Some(2),
            _ => Some(0),
        };
    }

    fn begin_edit(&mut self, _interface: &NativeInterfaceRef) {
        self.set_expanded(!self.expanded);
    }

    fn end_edit(&mut self, _interface: &NativeInterfaceRef) {}

    fn begin_sub_edit(&mut self, sub: &str, interface: &NativeInterfaceRef) {
        let idx = match sub {
            "r" => 0,
            "g" => 1,
            "b" => 2,
            _ => return,
        };
        let val = format!("{:.2}", self.value[idx]);
        if let Some(value) = &self.channel_values[idx] {
            let _ = value.set(val);
        }
        if let Some(editing) = &self.channel_editing[idx] {
            let _ = editing.set(true);
        }
        if let Some(e) = self.channels[idx].edit {
            let _ = interface.rml_ui().element_focus(e);
            let _ = interface.rml_ui().element_form_control_input_select(e);
        }
    }

    fn select_edit(&mut self, interface: &NativeInterfaceRef) {
        if let Some(idx) = self.drag_channel {
            if let Some(e) = self.channels[idx].edit {
                let _ = interface.rml_ui().element_focus(e);
                let _ = interface.rml_ui().element_form_control_input_select(e);
            }
        }
    }

    fn read_sub_field(&mut self, sub: &str, _interface: &NativeInterfaceRef) -> Option<FieldValue> {
        match sub {
            "r" => {
                self.read_channel_input(0);
                Some(FieldValue::Color(self.value))
            }
            "g" => {
                self.read_channel_input(1);
                Some(FieldValue::Color(self.value))
            }
            "b" => {
                self.read_channel_input(2);
                Some(FieldValue::Color(self.value))
            }
            "hex" => {
                self.read_hex_input();
                Some(FieldValue::Color(self.value))
            }
            _ => None,
        }
    }
}
