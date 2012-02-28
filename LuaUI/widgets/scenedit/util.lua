function CallListeners(listeners, ...)
    for i = 1, #listeners do
        local listener = listeners[i]
        listener(...)
    end
end

function MakeConfirmButton(dialog, btnConfirm)
    dialog.OnConfirm = {}
    btnConfirm.OnClick = {
        function()
            CallListeners(dialog.OnConfirm)
            dialog:Dispose()
        end
    }
end
