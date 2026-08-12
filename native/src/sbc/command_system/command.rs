use super::context::Context;
use super::registry::{parse_command, CommandParseError, CommandRegistration};

pub type CommandId = u64;

pub type Merger = fn(Vec<Box<dyn Command>>) -> Box<dyn Command>;

pub trait Command: 'static {
    fn execute(&mut self, ctx: &mut Context);

    fn unexecute(&mut self, ctx: &mut Context) {
        let _ = ctx;
    }

    fn undoable(&self) -> bool {
        true
    }

    fn merger(&self) -> Merger {
        |group| Box::new(CompoundCommand { commands: group })
    }

    fn type_id(&self) -> std::any::TypeId {
        std::any::TypeId::of::<Self>()
    }

    fn serialize_log(&self) -> serde_json::Value {
        serde_json::Value::Null
    }
}

pub struct CompoundCommand {
    pub commands: Vec<Box<dyn Command>>,
}

impl Command for CompoundCommand {
    fn execute(&mut self, ctx: &mut Context) {
        for cmd in &mut self.commands {
            cmd.execute(ctx);
        }
    }

    fn unexecute(&mut self, ctx: &mut Context) {
        for cmd in self.commands.iter_mut().rev() {
            cmd.unexecute(ctx);
        }
    }
}

inventory::submit! {
    CommandRegistration {
        class_name: "CompoundCommand",
        handler: parse_compound_command,
        type_id_fn: std::any::TypeId::of::<CompoundCommand>,
    }
}

fn parse_compound_command(
    value: serde_json::Value,
) -> Result<Option<Box<dyn Command>>, CommandParseError> {
    let Some(serde_json::Value::Array(inner)) = value.get("commands") else {
        return Ok(None);
    };
    let mut commands = Vec::with_capacity(inner.len());
    for cmd_value in inner {
        match parse_command(cmd_value.clone())? {
            Some(cmd) => commands.push(cmd),
            None => return Ok(None),
        }
    }
    if commands.is_empty() {
        return Ok(None);
    }
    Ok(Some(Box::new(CompoundCommand { commands })))
}
