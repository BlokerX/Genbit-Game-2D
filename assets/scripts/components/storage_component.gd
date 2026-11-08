class_name StorageComponent
extends Node
## Komponent magazynu / skrzyni przechowujący przedmioty w slotach (SlotData).

@export_group("Oprawa dźwiękowa")
## Dźwięk odtwarzany przy otwarciu interfejsu skrzyni.
@export var open_feedback: FeedbackCue = preload(
	"res://assets/data/feedback/environment/chest_open.tres"
)

#region Storage stats
## Rozmiar skrzyni (liczba slotów).
@export var slots_amount: int = 16
## Tablica slotów współdzieląca strukturę SlotData z ekwipunkiem gracza.
@export var slots: Array[SlotData] = []
## Opcjonalna bezpośrednia referencja do komponentu interakcji (jeśli puste, zostanie wyszukana automatycznie u rodzica).
@export var interactable_comp: InteractableComponent
#endregion

#region Signals
## Sygnał do powiadomienia UI o zmianie zawartości skrzyni.
signal storage_updated
## Sygnał wysyłany do UI po wejściu w interakcję ze skrzynią.
signal storage_opened(storage_reference: StorageComponent)
## Sygnał emitowany tuż przed zniszczeniem skrzyni, aby UI bezpiecznie zamknęło okno.
signal storage_destroyed
#endregion

## Inicjalizacja pustych slotów wzorowana na inventory.gd
func _init() -> void:
	slots.resize(slots_amount)
	for i in range(slots_amount):
		slots[i] = SlotData.new()

func _ready() -> void:
	# Naprawa rozmiaru tablicy po nadpisaniu przez Inspektor
	if slots.size() < slots_amount:
		slots.resize(slots_amount)

	# Upewniamy się, że żaden slot nie jest "null" i odklejamy referencje startowych przedmiotów z Edytora
	for i in range(slots_amount):
		if slots[i] == null:
			slots[i] = SlotData.new()
		else:
			slots[i] = slots[i].duplicate(true)
			if not slots[i].is_empty():
				slots[i].item = slots[i].item.duplicate(true)
				slots[i].item.data = slots[i].item.data.create_unique_copy()

	# AUTO-RESOLVE: Jeśli nie przypisano InteractableComponent w Inspektorze, szukamy go u rodzica
	if interactable_comp == null and get_parent() != null:
		interactable_comp = get_parent().get_node_or_null("InteractableComponent") as InteractableComponent

	if interactable_comp != null and interactable_comp.has_signal("interacted"):
		if not interactable_comp.interacted.is_connected(_on_interacted):
			interactable_comp.interacted.connect(_on_interacted)

func _on_interacted(_interactor: Node) -> void:
	var storage_owner: Node2D = get_parent() as Node2D
	if open_feedback != null and is_instance_valid(storage_owner):
		GameFeedback.play_cue(open_feedback, null, storage_owner.global_position, storage_owner)
	storage_opened.emit(self)
	EventBus.open_storage_ui.emit(self)

# ----------------------------------------------------
# --- ZARZĄDZANIE INSTANCJAMI (Kompatybilne z ECS) ---
# ----------------------------------------------------

## Przyjmuje instancję do skrzyni (automatyczne szukanie miejsca).
## Zwraca null jeśli wszystko weszło, lub resztę instancji, jeśli zabrakło miejsca.
func insert_instance(instance_to_add: ItemInstance) -> ItemInstance:
	var add_amount: int = instance_to_add.state.get("amount", 1) if instance_to_add != null else 0
	if instance_to_add == null or add_amount <= 0:
		return null

	var max_stack: int = instance_to_add.get_max_stack()
	var is_stackable: bool = max_stack > 1

	# 1. Próbujemy uzupełnić istniejące stosy
	if is_stackable:
		for slot in slots:
			if not slot.is_empty() and slot.item.can_stack_with(instance_to_add):
				var slot_amount: int = slot.item.state.get("amount", 1)
				var available_space: int = max_stack - slot_amount

				if available_space > 0:
					var adding: int = mini(instance_to_add.state.get("amount", 1), available_space)
					slot.item.state["amount"] = slot_amount + adding
					instance_to_add.state["amount"] = instance_to_add.state.get("amount", 1) - adding

					if instance_to_add.state["amount"] <= 0:
						storage_updated.emit()
						return null # Całość zmieściła się w stosie!

	# 2. Szukamy dowolnego pustego slota od lewej
	for slot in slots:
		if slot.is_empty():
			slot.item = instance_to_add
			storage_updated.emit()
			return null

	# Brak miejsca - zwracamy instancję z powrotem do gracza/na ziemię
	return instance_to_add

## Wkłada instancję do KONKRETNEGO slotu (przydatne przy Drag & Drop w UI).
## Zwraca stary item (jeśli slot był zajęty) lub null, jeśli się udało.
func insert_instance_at(instance_to_add: ItemInstance, slot_index: int) -> ItemInstance:
	if slot_index < 0 or slot_index >= slots_amount:
		return instance_to_add

	var slot: SlotData = slots[slot_index]

	# Jeśli slot jest pusty
	if slot.is_empty():
		slot.item = instance_to_add
		storage_updated.emit()
		return null

	# Jeśli w slocie jest ten sam przedmiot - sprawdzamy czy można go stackować
	if slot.item.can_stack_with(instance_to_add):
		var max_stack: int = slot.item.get_max_stack()
		var slot_amount: int = slot.item.state.get("amount", 1)
		var available_space: int = max_stack - slot_amount

		if available_space > 0:
			var adding: int = mini(instance_to_add.state.get("amount", 1), available_space)
			slot.item.state["amount"] = slot_amount + adding
			instance_to_add.state["amount"] = instance_to_add.state.get("amount", 1) - adding

			if instance_to_add.state["amount"] <= 0:
				storage_updated.emit()
				return null
			else:
				storage_updated.emit()
				return instance_to_add # Zwraca resztę, która nie weszła do stacka

	# Jeśli w slocie jest inny przedmiot (lub brak miejsca) - Zamieniamy je miejscami!
	var old_instance: ItemInstance = slot.item
	slot.item = instance_to_add
	storage_updated.emit()
	return old_instance

## Wyciąga całą instancję (lub część) ze slotu. Zwraca wyciągnięty ItemInstance.
func remove_instance(slot_index: int, amount_to_remove: int = -1) -> ItemInstance:
	if slot_index < 0 or slot_index >= slots_amount:
		return null

	var slot: SlotData = slots[slot_index]
	if slot.is_empty():
		return null

	var current_slot_amount: int = slot.item.state.get("amount", 1)

	# Scenariusz 1: Zabieramy cały stack (lub wpisano wartość -1)
	if amount_to_remove == -1 or amount_to_remove >= current_slot_amount:
		var extracted_all: ItemInstance = slot.item
		slot.clear_slot()
		storage_updated.emit()
		return extracted_all

	# Scenariusz 2: Zabieramy tylko część sztuk (np. prawy przycisk myszy)
	var extracted_split: ItemInstance = slot.item.create_split_copy(amount_to_remove)
	slot.item.state["amount"] = current_slot_amount - amount_to_remove
	storage_updated.emit()
	return extracted_split
