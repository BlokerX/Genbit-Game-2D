@tool
class_name ItemInstance
extends Resource

## Sygnał emitowany zawsze, gdy stan (ilość/wytrzymałość) ulegnie zmianie
signal state_changed

# TARCZA 1: Setter na data. Kiedy w Inspektorze przypniesz "Miecz", 
# natychmiast odpali się konfiguracja jego komponentów!
@export var data: ItemData:
	set(value):
		data = value
		_initialize_components()
		emit_changed()

## Uniwersalny kontener na całkowity stan przedmiotu (ilość, ładunki, zepsucie)
@export var state: Dictionary = {}

@export_group("Szybka Edycja (Inspektor)")

## Pozwala ustawić ilość bezpośrednio w Inspektorze (1 nic nie ustawia)
@export var amount: int = 1:
	set(value):
		if value == 1:
			return
		if not state: state = {}
		state["amount"] = value
		emit_changed()
	get:
		return state.get("amount", 1) if state else 1

## Pozwala ręcznie uszkodzić przedmiot w Inspektorze (0 to pełna wytrzymałość)
@export var durability: int = 0:
	set(value):
		if value == 0:
			return
		if not state: state = {}
		state["durability"] = value
		emit_changed()
	get:
		return state.get("durability", 0) if state else 0

func _init(p_data: ItemData = null, p_amount: int = 1) -> void:
	state = {}
	data = p_data
	state["amount"] = p_amount # Zapisujemy początkową ilość
	_initialize_components()

func _initialize_components() -> void:
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
		
	# 1. Podstawowy test tożsamości (Sprawdzamy ID)
	if data.item_id != other.data.item_id:
		return false
		
	# 2. TARCZA ECS: Sprawdzamy, czy stany przedmiotów są IDENTYCZNE.
	# Zabezpiecza przed "leczeniem" mieczy lub łączeniem karabinów z inną amunicją!
	for key in state.keys():
		if key == "amount": continue # Ilość nas nie interesuje przy porównywaniu
		if not other.state.has(key) or state[key] != other.state[key]:
			return false
			
	for key in other.state.keys():
		if key == "amount": continue
		if not state.has(key) or state[key] != other.state[key]:
			return false
			
	return true
