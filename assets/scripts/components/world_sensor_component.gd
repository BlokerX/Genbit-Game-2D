extends Node
class_name WorldSensorComponent

## Uniwersalny, zaawansowany czujnik świata gry.
## Podepnij sygnał (np. body_entered z Area2D, drzwi lub pressed z Buttona) do funkcji trigger().

@export_group("Reakcja (Co ma się stać?)")
## Lista efektów (np. UpdateQuestEffect, DamageEffect, GiveItemEffect), które zostaną wywołane.
@export var consequences: Array[Effect] = []
## Opóźnienie przed wywołaniem efektów (w sekundach). Buduje napięcie.
@export var delay_seconds: float = 0.0

@export_group("Ograniczenia i Timery")
## Tylko gracz (węzeł z grupy 'Player') może aktywować ten czujnik. Ignoruje wrogów i pociski.
@export var only_player_can_trigger: bool = false
## Ile razy czujnik może zadziałać? (0 = nieskończoność, 1 = tylko raz)
@export var max_triggers: int = 0
## Czas stygnięcia między kolejnymi aktywacjami (w sekundach).
@export var cooldown_seconds: float = 0.0

@export_group("Filtry Fabularne (Opcjonalne)")
## Czujnik zadziała TYLKO, jeśli gracz ma aktywne to konkretne zadanie.
@export var required_quest: QuestData
## Jeśli ustawione na coś innego niż -1, czujnik zadziała TYLKO na tym konkretnym etapie Questa.
@export var required_quest_stage: int = -1

@export_group("Filtry Ekwipunku (Opcjonalne)")
## Czujnik zadziała TYLKO, jeśli gracz posiada ten przedmiot (np. Klucz).
@export var required_item: ItemData
## Ile sztuk przedmiotu gracz musi posiadać, aby czujnik zadziałał?
@export var required_item_amount: int = 1
## Czy po pomyślnej aktywacji czujnik ma zniszczyć (zabrać) wymaganą ilość z ekwipunku?
@export var consume_required_item: bool = false

@export_group("Autodestrukcja (Optymalizacja)")
## Czy po wyczerpaniu limitu aktywacji (max_triggers) usunąć sam ten komponent z pamięci?
@export var destroy_self_after_max: bool = true
## Czy po wyczerpaniu limitu usunąć CAŁEGO RODZICA (np. znikające drzwi, pułapka lub moneta)?
@export var destroy_parent_after_max: bool = false

# --- ZMIENNE WEWNĘTRZNE ---
## Licznik przechowujący informację, ile razy ten czujnik już zadziałał.
var _trigger_count: int = 0
## Flaga zabezpieczająca, która zapobiega spamowaniu czujnika w trakcie odliczania czasu stygnięcia.
var _is_on_cooldown: bool = false

## Główna funkcja, którą łączysz z sygnałami (np. area_entered, body_entered).
## Parametr 'activator' to opcjonalny Node, który wywołał czujnik (np. gracz).
func trigger(activator: Node = null) -> void:
	if _is_on_cooldown: 
		# Ciche ignorowanie, by nie spamować konsoli, gdy gracz po prostu stoi w strefie
		return
		
	if max_triggers > 0 and _trigger_count >= max_triggers: 
		return
	
	if only_player_can_trigger and activator != null:
		if not activator.is_in_group("Player"): 
			return

	# Zatrzymujemy aktywację, jeśli filtry zwrócą 'false' (wewnątrz wypiszą też powód)
	if not _check_filters():
		return

	# --- FAKTYCZNA AKTYWACJA CZUJNIKA ---
	_trigger_count += 1
	print("WorldSensor [", get_parent().name, "]: Aktywacja pomyślna! (Użycie: ", _trigger_count, ")")
	
	# Pobieramy przedmioty z ekwipunku dopiero po pozytywnej weryfikacji
	_consume_items_if_needed()
	
	if cooldown_seconds > 0.0:
		_start_cooldown()

	if delay_seconds > 0.0:
		await get_tree().create_timer(delay_seconds).timeout
		if not is_inside_tree(): return # Zabezpieczenie na wypadek zniszczenia w trakcie czekania

	_execute_effects(activator)
	_handle_destruction()

## Sprawdza wszystkie nałożone filtry (Questy, Ekwipunek). 
## Zwraca 'true' jeśli można aktywować czujnik, lub 'false' wyrzucając błąd do konsoli.
func _check_filters() -> bool:
	# 1. Sprawdzanie Questów
	if required_quest != null:
		if not QuestManager.active_quests.has(required_quest.id):
			print("WorldSensor: Odrzucono. Wymagane zadanie [", required_quest.title, "] nie jest aktywne.")
			return false
			
		if required_quest_stage != -1:
			var current_stage = QuestManager.active_quests[required_quest.id]["stage"]
			if current_stage != required_quest_stage:
				print("WorldSensor: Odrzucono. Wymagany etap zadania to [", required_quest_stage, "], a gracz jest na [", current_stage, "].")
				return false
				
	# 2. Sprawdzanie Ekwipunku (Wymaga Gracza na scenie)
	if required_item != null:
		var player = get_tree().get_first_node_in_group("Player")
		if not player or not player.has_method("get_inventory"): 
			print("WorldSensor: Błąd! Nie znaleziono węzła Gracza lub nie posiada on funkcji get_inventory().")
			return false
			
		var inv = player.get_inventory()
		if not inv.has_items(required_item.item_id, required_item_amount):
			print("WorldSensor: Odrzucono. Brak przedmiotu [", required_item.item_name, "] w ilości min. ", required_item_amount, " szt.")
			return false

	return true

## Jeśli czujnik wymagał przedmiotu i miał zaznaczoną opcję jego zużycia, zabiera go z ekwipunku Gracza.
func _consume_items_if_needed() -> void:
	if required_item != null and consume_required_item:
		var player = get_tree().get_first_node_in_group("Player")
		if player and player.has_method("get_inventory"):
			var inv = player.get_inventory()
			inv.consume_ingredients(required_item.item_id, required_item_amount)
			print("WorldSensor: Zużyto wymagany przedmiot [", required_item.item_name, "] x", required_item_amount)

## Przetwarza całą listę przypisanych efektów i nakłada je na cel (domyślnie Gracza).
func _execute_effects(activator: Node) -> void:
	# Szukamy, na kogo nałożyć efekt (najlepiej na tego, kto wdepnął w czujnik)
	var target = activator
	if target == null or not target.has_method("receive_effect"):
		target = get_tree().get_first_node_in_group("Player")
		
	if target and target.has_method("receive_effect"):
		for effect in consequences:
			if effect != null:
				target.receive_effect(effect.duplicate(true))
			
## Uruchamia asynchroniczny stoper blokujący czujnik na określony czas.
func _start_cooldown() -> void:
	_is_on_cooldown = true
	await get_tree().create_timer(cooldown_seconds).timeout
	_is_on_cooldown = false

## Sprawdza, czy czujnik osiągnął maksymalny limit użyć. Jeśli tak, usuwa go z pamięci.
func _handle_destruction() -> void:
	if max_triggers > 0 and _trigger_count >= max_triggers:
		if destroy_parent_after_max:
			print("WorldSensor: Limit wyczerpany. Autodestrukcja RODZICA (", get_parent().name, ").")
			var parent = get_parent()
			if parent:
				parent.queue_free()
		elif destroy_self_after_max:
			print("WorldSensor: Limit wyczerpany. Autodestrukcja CZUJNIKA.")
			queue_free()
