use serde_json::{Map, Number, Value};

pub(crate) fn table_file(value: &Value) -> String {
    format!("return {}\n", table(value, 0))
}

pub(crate) fn mapinfo_file(map_info: &Value, extra: &str) -> String {
    format!("local mapInfo ={}\n{}", table(map_info, 0), extra)
}

pub(crate) fn table(value: &Value, indent: usize) -> String {
    match value {
        Value::Null => "nil".to_string(),
        Value::Bool(v) => v.to_string(),
        Value::Number(v) => number(v),
        Value::String(v) => quote(v),
        Value::Array(values) => array(values, indent),
        Value::Object(map) => object(map, indent),
    }
}

pub(crate) fn start_script_table(key: &str, value: &Value, indent: usize) -> String {
    let istr = "\t".repeat(indent);
    let cstr = "\t".repeat(indent + 1);
    let mut out = format!("{istr}[{key}]\n{istr}{{\n");
    if let Some(map) = value.as_object() {
        let mut keys: Vec<&String> = map.keys().collect();
        keys.sort_by_key(|k| k.to_lowercase());
        let mut table_keys = Vec::new();
        for key in &keys {
            let Some(v) = map.get(*key) else {
                continue;
            };
            if v.is_object() {
                table_keys.push(*key);
            } else {
                out.push_str(&cstr);
                out.push_str(key);
                out.push_str(" = ");
                out.push_str(&start_script_scalar(v));
                out.push_str(";\n");
            }
        }
        if !table_keys.is_empty() {
            out.push('\n');
            for key in table_keys {
                if let Some(v) = map.get(key) {
                    out.push_str(&start_script_table(key, v, indent + 1));
                }
            }
        }
    }
    out.push_str(&format!("{istr}}}\n\n"));
    out
}

fn array(values: &[Value], indent: usize) -> String {
    if values.is_empty() {
        return "{}".to_string();
    }
    let next = indent + 2;
    let mut out = String::from("{\n");
    for value in values {
        out.push_str(&" ".repeat(next));
        out.push_str(&table(value, next));
        out.push_str(",\n");
    }
    out.push_str(&" ".repeat(indent));
    out.push('}');
    out
}

fn object(map: &Map<String, Value>, indent: usize) -> String {
    if map.is_empty() {
        return "{}".to_string();
    }
    let next = indent + 2;
    let mut keys: Vec<&String> = map.keys().collect();
    keys.sort_by_key(|a| key_sort(a));
    let mut out = String::from("{\n");
    for key in keys {
        let Some(value) = map.get(key) else {
            continue;
        };
        out.push_str(&" ".repeat(next));
        out.push_str(&key_expr(key));
        out.push_str(" = ");
        out.push_str(&table(value, next));
        out.push_str(",\n");
    }
    out.push_str(&" ".repeat(indent));
    out.push('}');
    out
}

fn key_sort(key: &str) -> (u8, String) {
    if let Ok(num) = key.parse::<i64>() {
        (0, format!("{num:020}"))
    } else {
        (1, key.to_string())
    }
}

fn key_expr(key: &str) -> String {
    if let Ok(num) = key.parse::<i64>() {
        return format!("[{num}]");
    }
    if is_identifier(key) && !is_lua_keyword(key) {
        key.to_string()
    } else {
        format!("[{}]", quote(key))
    }
}

fn is_identifier(key: &str) -> bool {
    let mut chars = key.chars();
    let Some(first) = chars.next() else {
        return false;
    };
    if !(first.is_ascii_alphabetic() || first == '_') {
        return false;
    }
    chars.all(|c| c.is_ascii_alphanumeric() || c == '_')
}

fn is_lua_keyword(key: &str) -> bool {
    matches!(
        key,
        "and"
            | "break"
            | "do"
            | "else"
            | "elseif"
            | "end"
            | "false"
            | "for"
            | "function"
            | "if"
            | "in"
            | "local"
            | "nil"
            | "not"
            | "or"
            | "repeat"
            | "return"
            | "then"
            | "true"
            | "until"
            | "while"
    )
}

fn quote(value: &str) -> String {
    let mut out = String::from("\"");
    for ch in value.chars() {
        match ch {
            '\\' => out.push_str("\\\\"),
            '"' => out.push_str("\\\""),
            '\n' => out.push_str("\\n"),
            '\r' => out.push_str("\\r"),
            '\t' => out.push_str("\\t"),
            c if c.is_control() => out.push_str(&format!("\\{}", c as u32)),
            c => out.push(c),
        }
    }
    out.push('"');
    out
}

fn number(value: &Number) -> String {
    value.to_string()
}

fn start_script_scalar(value: &Value) -> String {
    match value {
        Value::Bool(v) => {
            if *v {
                "1".to_string()
            } else {
                "0".to_string()
            }
        }
        Value::Number(v) => v.to_string(),
        Value::String(v) => v.clone(),
        Value::Null => String::new(),
        Value::Array(_) | Value::Object(_) => String::new(),
    }
}
