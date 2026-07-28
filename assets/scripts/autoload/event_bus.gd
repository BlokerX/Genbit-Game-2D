extends Node

## Zarządzanie widocznością UI
signal open_storage_ui(storage_reference: Node)
signal close_storage_ui()

## Przekazuje kto został kliknięty, który to slot i jakim przyciskiem (-1 to Shift+Lewy)
signal slot_clicked(parent_reference: Node, slot_index: int, button_index: int)

signal ui_state_changed(is_open: bool)
