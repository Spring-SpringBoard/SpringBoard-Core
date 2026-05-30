use super::context::Context;

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
