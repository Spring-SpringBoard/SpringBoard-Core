use spring_native::prelude::{Error, NativeInterfaceRef};

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
    value: [f32; 4],
    swatch: Option<u64>,
    editor: Option<u64>,
    hex_input: Option<u64>,
    channels: [ChannelElems; 3],
    expanded: bool,
    drag_channel: Option<usize>, // 0=R, 1=G, 2=B
}

struct ChannelElems {
    display: Option<u64>,
    edit: Option<u64>,
}

impl ChannelElems {
    const fn none() -> Self {
        ChannelElems {
            display: None,
            edit: None,
        }
    }
}

impl ColorField {
    pub(crate) fn new(name: impl Into<String>, title: impl Into<String>) -> Self {
        ColorField {
            name: name.into(),
            title: title.into(),
            value: [1.0, 1.0, 1.0, 1.0],
            swatch: None,
            editor: None,
            hex_input: None,
            channels: [
                ChannelElems::none(),
                ChannelElems::none(),
                ChannelElems::none(),
            ],
            expanded: false,
            drag_channel: None,
        }
    }

    #[allow(dead_code)]
    pub(crate) fn get(&self) -> [f32; 4] {
        self.value
    }

    // ── Conversions ──

    fn to_css(c: [f32; 4]) -> String {
        format!(
            "rgb({}, {}, {})",
            (c[0].clamp(0.0, 1.0) * 255.0) as u8,
            (c[1].clamp(0.0, 1.0) * 255.0) as u8,
            (c[2].clamp(0.0, 1.0) * 255.0) as u8,
        )
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

    // ── DOM sync helpers ──

    fn sync_swatch(&self, interface: &NativeInterfaceRef) {
        if let Some(e) = self.swatch {
            let _ = interface.rml_ui().element_set_attribute(
                e,
                "style",
                &format!("background-color: {};", Self::to_css(self.value)),
            );
        }
    }

    fn sync_channels(&self, interface: &NativeInterfaceRef) {
        for (i, ch) in self.channels.iter().enumerate() {
            let val = format!("{:.2}", self.value[i]);
            if let Some(e) = ch.display {
                let _ = interface.rml_ui().element_set_inner_rml(e, &val);
            }
            if let Some(e) = ch.edit {
                let _ = interface.rml_ui().element_set_attribute(e, "value", &val);
            }
        }
    }

    fn sync_hex(&self, interface: &NativeInterfaceRef) {
        if let Some(e) = self.hex_input {
            let _ = interface
                .rml_ui()
                .element_set_attribute(e, "value", &Self::to_hex(self.value));
        }
    }

    fn set_expanded(&mut self, interface: &NativeInterfaceRef, on: bool) {
        self.expanded = on;
        if let Some(e) = self.editor {
            let style = if on { "" } else { "display: none;" };
            let _ = interface.rml_ui().element_set_attribute(e, "style", style);
        }
    }

    fn read_channel_input(&mut self, idx: usize, interface: &NativeInterfaceRef) {
        let ch = &self.channels[idx];
        if let Some(e) = ch.edit {
            if let Ok(Some(text)) = interface.rml_ui().element_get_value(e) {
                self.value[idx] = text.parse().unwrap_or(self.value[idx]).clamp(0.0, 1.0);
            }
            let _ = interface
                .rml_ui()
                .element_set_attribute(e, "style", "display: none;");
        }
        if let Some(e) = self.channels[idx].display {
            let _ = interface.rml_ui().element_set_attribute(e, "style", "");
        }
        self.sync_swatch(interface);
        self.sync_channels(interface);
    }

    fn read_hex_input(&mut self, interface: &NativeInterfaceRef) {
        if let Some(e) = self.hex_input {
            if let Ok(Some(text)) = interface.rml_ui().element_get_value(e) {
                self.value = Self::parse_hex_or_csv(&text);
            }
        }
        self.sync_swatch(interface);
        self.sync_channels(interface);
    }
}

impl Field for ColorField {
    fn name(&self) -> &str {
        &self.name
    }

    fn generate_rml(&self) -> String {
        let title = escape_rml(self.title.trim_end_matches(':'));
        let bg = Self::to_css(self.value);
        let hex = Self::to_hex(self.value);
        let n = &self.name;
        let channels: String = ['r', 'g', 'b']
            .iter()
            .enumerate()
            .map(|(i, &ch)| {
                let val = format!("{:.2}", self.value[i]);
                format!(
                    r#"<div class="field-inline"><span class="channel-label {ch}">{ch}</span>"#
                ) + &format!(
                    r#"<button id="field-{n}-{ch}-display" class="numeric-display compact color-channel">{val}</button>"#,
                ) + &format!(
                    r#"<input type="text" id="field-{n}-{ch}-edit" class="numeric-edit compact" value="{val}" style="display: none;"/></div>"#,
                )
            })
            .collect();

        format!(
            r#"<div class="field-row"><span class="field-label">{title}:</span><div class="color-field">"#
        ) + &format!(
            r#"<button id="field-{n}-swatch" class="color-swatch" style="background-color: {bg};"></button>"#,
        ) + &format!(r#"<div id="field-{n}-editor" class="color-editor" style="display: none;">"#,)
            + &format!(r#"<input type="text" id="field-{n}-hex" class="color-hex" value="{hex}"/>"#,)
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
        self.swatch = element_by_id(interface, document, &format!("field-{n}-swatch"));
        self.editor = element_by_id(interface, document, &format!("field-{n}-editor"));
        self.hex_input = element_by_id(interface, document, &format!("field-{n}-hex"));

        for (i, ch) in ['r', 'g', 'b'].iter().enumerate() {
            self.channels[i].display =
                element_by_id(interface, document, &format!("field-{n}-{ch}-display"));
            self.channels[i].edit =
                element_by_id(interface, document, &format!("field-{n}-{ch}-edit"));
        }

        // Swatch: click to toggle expand
        if let Some(e) = self.swatch {
            on_pointer(interface, e, self.name.clone(), interactions)?;
        }
        // Hex input: change → read
        if let Some(e) = self.hex_input {
            on_change(interface, e, format!("{}-hex", self.name), changes)?;
        }
        // Each channel: drag + edit
        for (i, ch) in ['r', 'g', 'b'].iter().enumerate() {
            let sub_name = format!("{}-{ch}", self.name);
            if let Some(e) = self.channels[i].display {
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

    fn write_to_dom(&self, interface: &NativeInterfaceRef) -> Result<(), Error> {
        self.sync_swatch(interface);
        self.sync_channels(interface);
        self.sync_hex(interface);
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

    fn drag(&mut self, dx: f32, interface: &NativeInterfaceRef) {
        let idx = self.drag_channel.unwrap_or(0);
        self.value[idx] = (self.value[idx] + dx * CHANNEL_STEP).clamp(0.0, 1.0);
        self.sync_swatch(interface);
        self.sync_channels(interface);
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

    fn begin_edit(&mut self, interface: &NativeInterfaceRef) {
        self.set_expanded(interface, !self.expanded);
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
        if let Some(e) = self.channels[idx].display {
            let _ = interface
                .rml_ui()
                .element_set_attribute(e, "style", "display: none;");
        }
        if let Some(e) = self.channels[idx].edit {
            let _ = interface.rml_ui().element_set_attribute(e, "style", "");
            let _ = interface.rml_ui().element_set_attribute(e, "value", &val);
            let _ = interface.rml_ui().element_focus(e);
        }
    }

    fn read_sub_field(&mut self, sub: &str, interface: &NativeInterfaceRef) -> Option<FieldValue> {
        match sub {
            "r" => {
                self.read_channel_input(0, interface);
                Some(FieldValue::Color(self.value))
            }
            "g" => {
                self.read_channel_input(1, interface);
                Some(FieldValue::Color(self.value))
            }
            "b" => {
                self.read_channel_input(2, interface);
                Some(FieldValue::Color(self.value))
            }
            "hex" => {
                self.read_hex_input(interface);
                Some(FieldValue::Color(self.value))
            }
            _ => None,
        }
    }
}
