use crate::sbc::command_system::command::CommandId;
use crate::sbc::command_system::context::Context;
use crate::sbc::io::io_api::{IoJob, IoOutcome};
use crate::sbc::{lua_bridge, sbc::SBC};

/// Notify LuaUI that `ctx.current_command_id` has fully applied. Rides the IO
/// FIFO so it lands after the command's own file writes, not before them.
pub(crate) fn submit_native_command_completed(ctx: &mut Context) {
    ctx.submit_io(Box::new(NativeCommandCompletedJob {
        command_id: ctx.current_command_id,
    }));
}

struct NativeCommandCompletedJob {
    command_id: CommandId,
}

impl IoJob for NativeCommandCompletedJob {
    fn run(self: Box<Self>) -> Box<dyn IoOutcome> {
        Box::new(NativeCommandCompletedOutcome {
            command_id: self.command_id,
        })
    }
}

struct NativeCommandCompletedOutcome {
    command_id: CommandId,
}

impl IoOutcome for NativeCommandCompletedOutcome {
    fn apply(self: Box<Self>, sbc: &mut SBC) {
        lua_bridge::widget_command(
            sbc.interface(),
            serde_json::json!({
                "className": "WidgetNativeCommandCompleted",
                "cmdID": self.command_id,
            }),
        );
    }
}
