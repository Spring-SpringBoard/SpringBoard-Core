use super::context::Context;
use super::registry::{parse_command, CommandParseError, CommandRegistration};

/// Stable id for one command history entry.
///
/// Lua assigns `__cmd_id` before sending commands to Rust. Resource-owning
/// systems can use this id to associate external state with the command history
/// entry and release it when history evicts or clears that entry.
pub type CommandId = u64;

/// Folds a stream's commands into the single one that lands on the undo stack.
pub type Merger = fn(Vec<Box<dyn Command>>) -> Box<dyn Command>;

pub trait Command {
    fn execute(&mut self, ctx: &mut Context);

    /// Only called when `undoable()`.
    fn unexecute(&mut self, ctx: &mut Context) {
        let _ = ctx;
    }

    fn undoable(&self) -> bool {
        true
    }

    /// The function that folds a stream led by this command into one. Returned
    /// as a plain `fn` (capturing nothing) so the caller can drop its borrow of
    /// the first command before handing over the owned group. Defaults to a
    /// [`CompoundCommand`]; override to fold more cheaply.
    fn merger(&self) -> Merger {
        |group| Box::new(CompoundCommand { commands: group })
    }
}

/// A command run for its live effect only: it applies to the engine and never
/// reaches the undo history.
///
/// The colour picker sends one per drag frame so the scene follows the cursor
/// without burying the undo stack; the committed value arrives afterwards as a
/// normal command. A previewing caller must restore the original value (as a
/// preview) before committing, or the committed command captures the previewed
/// state as the value undo would restore.
pub struct PreviewCommand {
    pub inner: Box<dyn Command>,
}

impl Command for PreviewCommand {
    fn execute(&mut self, ctx: &mut Context) {
        self.inner.execute(ctx);
    }

    fn undoable(&self) -> bool {
        false
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

// The editor batches object/terrain edits into a `CompoundCommand` (placement,
// multi-select, drag streams). Parse each inner command by its `className` and
// accept the batch only when every command has a native handler, preserving
// all-or-nothing execution instead of silently dropping unknown entries.
// TODO: Candidate for removal once commands are fully native; this transitional
// parsing path re-walks the batch and is not the shape we want long-term.
inventory::submit! {
    CommandRegistration {
        class_name: "CompoundCommand",
        handler: parse_compound_command,
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
