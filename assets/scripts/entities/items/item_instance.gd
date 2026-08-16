class_name ItemInstance
extends Resource

## Sygnał emitowany zawsze, gdy stan (ilość/wytrzymałość) ulegnie zmianie
signal state_changed

@export var data: ItemData
## Uniwersalny kontener na całkowity stan przedmiotu (ilość, ładunki, zepsucie)
@export var state: Dictionary = {}

func _init(p_data: ItemData = null, p_amount: int = 1) -> void:
	data = p_data
	state["amount"] = p_amount # Zapisujemy początkową ilość
	
	if data != null and data.components != null:
		for comp in data.components:
			if comp != null and comp.has_method("initialize_state"):
				comp.initialize_state(self)

# =====================================================================
# SYSTEM ZUŻYWANIA (Samozarządzanie)
# =====================================================================

## Odejmuje wytrzymałość. Jeśli spadnie do zera, automatycznie zjada 1 sztukę.
func consume_durability(amount: int = 1) -> void:
	if state.has("durability"):
		state["durability"] -= amount
		if state["durability"] <= 0:
			consume_amount(1)
		else:
			state_changed.emit()

## Odejmuje ilość ze stacka. Automatycznie odnawia wytrzymałość nowej sztuki.
func consume_amount(count: int = 1) -> void:
	if state.has("amount"):
		state["amount"] -= count
		if state["amount"] > 0:
			_reset_durability_from_components()
		state_changed.emit()

## Prywatna funkcja: Szuka komponentu Durability, by zresetować wytrzymałość nowej sztuki
func _reset_durability_from_components() -> void:
	if data != null and data.components != null:
		for comp in data.components:
			# Pobieramy maksymalną wytrzymałość z odpowiedniego klocka!
			if comp.get_script().resource_path.ends_with("durability_component.gd"):
				state["durability"] = comp.max_durability
				break

# =====================================================================
# SYSTEM ŁĄCZENIA I PORÓWNYWANIA PRZEDMIOTÓW 
# =====================================================================
func can_stack_with(other: ItemInstance) -> bool:
	if other == null or data == null or other.data == null:
		return false
		
	# 1. Podstawowy test tożsamości (Sprawdzamy StringName!)
	if data.item_id != other.data.item_id:
		return false
		
	# Uwaga: Dokładne sprawdzanie stanu (np. czy zepsutego miecza nie łączymy z nowym)
	# zostanie przeniesione do StackComponent w następnej fazie. Na razie zwracamy true.
	return true
