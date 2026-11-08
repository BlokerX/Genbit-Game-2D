@tool
class_name ItemInstance
extends Resource
## Przechowuje dynamiczny stan konkretnego egzemplarza przedmiotu w świecie gry (ilość, wytrzymałość, naboje).

const DEFAULT_STACK_AMOUNT: int = 1
const DEFAULT_DURABILITY: int = 0

## Sygnał emitowany zawsze, gdy stan (ilość/wytrzymałość/ładunki) ulegnie zmianie.
signal state_changed

# Setter na data: kiedy w Inspektorze przypniesz szablon przedmiotu (np. "Miecz"),
# natychmiast odpali się konfiguracja jego komponentów.
@export var data: ItemData:
	set(value):
		data = value
		_initialize_components()
		emit_changed()

## Uniwersalny kontener na całkowity stan przedmiotu (ilość, ładunki, zepsucie, amunicja).
@export var state: Dictionary = {}

@export_group("Szybka Edycja (Inspektor)")
## Pozwala ustawić ilość bezpośrednio w Inspektorze (wspiera również powrót do wartości 1!).
@export var amount: int = DEFAULT_STACK_AMOUNT:
	set(value):
		if state == null:
			state = {}
		var safe_amount: int = value if value == -1 else maxi(0, value)
		if state.get("amount", DEFAULT_STACK_AMOUNT) == safe_amount and state.has("amount"):
			return
		state["amount"] = safe_amount
		emit_changed()
	get:
		return state.get("amount", DEFAULT_STACK_AMOUNT) if state != null else DEFAULT_STACK_AMOUNT

## Pozwala ręcznie zmienić wytrzymałość przedmiotu w Inspektorze (wartość 0 resetuje do pełnej wytrzymałości z komponentu).
@export var durability: int = DEFAULT_DURABILITY:
	set(value):
		if state == null:
			state = {}
		if value <= 0:
			_reset_durability_from_components()
		else:
			state["durability"] = value
		emit_changed()
	get:
		return state.get("durability", DEFAULT_DURABILITY) if state != null else DEFAULT_DURABILITY

func _init(p_data: ItemData = null, p_amount: int = DEFAULT_STACK_AMOUNT) -> void:
	state = {}
	state["amount"] = p_amount # Zapisujemy początkową ilość przed inicjalizacją komponentów
	data = p_data
	_initialize_components()

func _initialize_components() -> void:
	if state == null:
		state = {}
	if not state.has("amount"):
		state["amount"] = DEFAULT_STACK_AMOUNT
	if data != null and data.components != null:
		for comp in data.components:
			if comp != null and comp.has_method("initialize_state"):
				comp.initialize_state(self)

## Tworzy wydzieloną instancję przedmiotu (np. przy dzieleniu stosu prawym kliknięciem lub wyrzucaniu 1 sztuki),
## kopiując cały stan (state) oraz tworząc niezależną kopię danych (create_unique_copy).
func create_split_copy(split_amount: int = DEFAULT_STACK_AMOUNT) -> ItemInstance:
	var unique_data: ItemData = data.create_unique_copy() if data != null else null
	var copy_inst: ItemInstance = ItemInstance.new(unique_data, split_amount)
	if state != null:
		copy_inst.state = state.duplicate(true)
	copy_inst.state["amount"] = split_amount
	return copy_inst

# =====================================================================
# SYSTEM ZUŻYWANIA (Samozarządzanie)
# =====================================================================

## Odejmuje wytrzymałość. Jeśli spadnie do zera, automatycznie zjada 1 sztukę przedmiotu!
func consume_durability(amount_to_consume: int = 1) -> void:
	if state.has("durability"):
		state["durability"] -= amount_to_consume
		if state["durability"] <= 0:
			consume_amount(1)
		else:
			state_changed.emit()

## Odejmuje ilość ze stacka. Automatycznie odnawia wytrzymałość kolejnej sztuki w stosie.
func consume_amount(count: int = 1) -> void:
	if state.has("amount"):
		# Wartość -1 oznacza nieskończony stack deweloperski
		if int(state["amount"]) == -1:
			_reset_durability_from_components()
			state_changed.emit()
			return

		state["amount"] -= count
		if state["amount"] > 0:
			_reset_durability_from_components()
		state_changed.emit()

## Zwraca maksymalną wytrzymałość zdefiniowaną w DurabilityComponent (lub 1, jeśli brak komponentu).
func get_max_durability() -> int:
	if data != null and data.components != null:
		for comp in data.components:
			if comp is DurabilityComponent:
				return (comp as DurabilityComponent).max_durability
	return 1

## Zwraca maksymalny rozmiar stosu zdefiniowany w StackComponent (lub 1, jeśli przedmiot nie jest stackowalny).
func get_max_stack() -> int:
	if data != null and data.components != null:
		for comp in data.components:
			if comp is StackComponent:
				return (comp as StackComponent).max_stack
	return DEFAULT_STACK_AMOUNT

## Prywatna funkcja: Szuka komponentu DurabilityComponent (zgodnie z SOLID bez sprawdzania ścieżek pliku),
## aby zresetować wytrzymałość nowej sztuki przedmiotu.
func _reset_durability_from_components() -> void:
	if data != null and data.components != null:
		for comp in data.components:
			if comp is DurabilityComponent:
				state["durability"] = (comp as DurabilityComponent).max_durability
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
	# Zabezpiecza przed "leczeniem" nadpsutych mieczy lub łączeniem karabinów z inną amunicją!
	for key in state.keys():
		if key == "amount":
			continue # Ilość nas nie interesuje przy porównywaniu kompatybilności stosu
		if not other.state.has(key) or state[key] != other.state[key]:
			return false

	for key in other.state.keys():
		if key == "amount":
			continue
		if not state.has(key) or state[key] != other.state[key]:
			return false

	return true
