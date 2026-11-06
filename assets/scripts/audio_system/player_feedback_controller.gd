class_name PlayerFeedbackController
extends Node

const FeedbackCueType = preload("res://assets/scripts/audio_system/feedback_cue.gd")
const ScreenFeedbackOverlayType = preload(
	"res://assets/scripts/audio_system/player_screen_feedback.gd"
)
# Keep aligned with FeedbackCue.VisualOrigin.TARGET's serialized enum value.
const VISUAL_ORIGIN_TARGET := 1
## Minimalny kwadrat prędkości ruchu (10 px/s)^2, powyżej którego odtwarzany jest dźwięk kroków.
const MIN_MOVEMENT_VELOCITY_SQUARED_FOR_STEP: float = 100.0

@export_group("Ekran i ruch")
## Zdrowie poniżej tej części maksymalnego HP uruchamia czerwoną obwódkę ekranu.
@export_range(0.0, 1.0, 0.01) var low_health_ratio: float = 0.25
## Dźwięk kroków; odstęp chroni przed odtwarzaniem co klatkę.
@export var movement_cue: FeedbackCueType
@export_range(0.1, 2.0, 0.05) var movement_sound_interval: float = 0.42
## Dźwięk rozpoczęcia rozmowy z NPC.
@export var dialogue_cue: FeedbackCueType

@export_group("Akcje Gracza")
## Przykładowa oprawa ataku wręcz, gdy gracz nie używa przedmiotu z własną oprawą.
@export var combat_cue: FeedbackCueType
## Oprawa podstawowego użycia przedmiotu, gdy przedmiot nie ma własnej konfiguracji.
@export var item_use_cue: FeedbackCueType
## Oprawa chwili śmierci i rozpoczęcia respawnu gracza.
@export var death_cue: FeedbackCueType

@export_group("Walka")
## Oprawa przyjęcia obrażeń przez gracza.
@export var damage_received_cue: FeedbackCueType
## Oprawa faktycznego trafienia zadanego przez gracza.
@export var damage_dealt_cue: FeedbackCueType

@export_group("Efekty statusu")
## Oprawa otrzymania efektu zamrożenia.
@export var freeze_cue: FeedbackCueType
## Oprawa innych pomyślnie nałożonych efektów.
@export var status_effect_cue: FeedbackCueType

@export_group("Ekwipunek i akcje")
## Oprawa udanego przeładowania.
@export var reload_cue: FeedbackCueType
## Oprawa próby przeładowania, gdy nie ma amunicji lub magazynek jest pełny.
@export var reload_failed_cue: FeedbackCueType
## Oprawa udanego podniesienia przedmiotu ze świata.
@export var item_pickup_cue: FeedbackCueType
## Oprawa wyrzucenia przedmiotu z ekwipunku.
@export var item_drop_cue: FeedbackCueType

var _player: PlayerCharacter
var _screen_overlay: CanvasLayer
var _movement_sound_timer: float = 0.0
var _active_freeze_effect_count: int = 0
var _last_known_health: int = -1

## Przypisuje kontroler do gracza, którego pozycja i sprite są źródłem oprawy.
func initialize(player: PlayerCharacter) -> void:
	_player = player
	_screen_overlay = player.get_node_or_null("PlayerScreenFeedback") as CanvasLayer
	if player.health_stats_script != null:
		if not player.health_stats_script.health_changed.is_connected(_on_player_health_changed):
			player.health_stats_script.health_changed.connect(_on_player_health_changed)
		if (
			player.health_stats_script.has_signal("health_healed")
			and not player.health_stats_script.health_healed.is_connected(_on_player_health_healed)
		):
			player.health_stats_script.health_healed.connect(_on_player_health_healed)
		_on_player_health_changed(
			player.health_stats_script.health, player.health_stats_script.max_health
		)

## Odtwarza akcję ataku gracza i umieszcza wizualny efekt przy celu lub graczu.
func play_combat(target: Node2D) -> void:
	var effect_position := _get_action_position(combat_cue, target)
	var v_target: Node2D = target if (combat_cue != null and combat_cue.visual_origin == VISUAL_ORIGIN_TARGET and is_instance_valid(target)) else _player
	_play_cue(combat_cue, _player.character_sprite, effect_position, _player, v_target)

## Odtwarza domyślną albo nadpisaną przez komponent przedmiotu oprawę użycia.
func play_item_use(cue: FeedbackCueType, target: Node2D) -> void:
	var selected_cue := cue if cue != null else item_use_cue
	var effect_position := _get_action_position(selected_cue, target)
	var v_target: Node2D = target if (selected_cue != null and selected_cue.visual_origin == VISUAL_ORIGIN_TARGET and is_instance_valid(target)) else _player
	_play_cue(selected_cue, _player.character_sprite, effect_position, _player, v_target)

## Odtwarza efekt trafienia zadanego przez gracza w pozycji trafionego celu.
func play_damage_dealt(target: Node2D) -> void:
	var effect_position := _player.global_position
	var v_target: Node2D = _player
	if is_instance_valid(target):
		effect_position = target.global_position
		v_target = target
	_play_cue(damage_dealt_cue, null, effect_position, _player, v_target)

## Odtwarza reakcję na otrzymanie obrażeń lub efektu statusu (zgodnie z OCP odpytuje metody Effect).
func play_received_effect(effect: Effect) -> void:
	if effect == null:
		return
	# Ignorujemy ciche/pasywne efekty (np. ze spodni/zbroi, aury pokoju) oraz samo odświeżenie czasu trwania
	if effect.is_silent_or_passive() or effect.has_meta("was_refreshed"):
		return

	if effect is DamageEffect:
		_play_cue(
			damage_received_cue, _player.character_sprite, _player.global_position, _player
		)
	elif effect is FreezeEffect:
		_play_cue(freeze_cue, _player.character_sprite, _player.global_position, _player)
	elif effect.is_beneficial():
		_play_cue(
			status_effect_cue, _player.character_sprite, _player.global_position, _player
		)
	else:
		_play_cue(
			status_effect_cue, _player.character_sprite, _player.global_position, _player
		)

## Odtwarza krok w określonych odstępach, kiedy gracz rzeczywiście się porusza.
func process_movement_feedback(delta: float, movement_velocity: Vector2) -> void:
	_movement_sound_timer = maxf(0.0, _movement_sound_timer - delta)
	if movement_velocity.length_squared() < MIN_MOVEMENT_VELOCITY_SQUARED_FOR_STEP or _movement_sound_timer > 0.0:
		return
	_play_cue(movement_cue, null, _player.global_position, _player)
	_movement_sound_timer = movement_sound_interval

## Odtwarza rozpoczęcie rozmowy.
func play_dialogue_start() -> void:
	_play_cue(dialogue_cue, null, _player.global_position, _player)

## Odtwarza oprawę śmierci przed rozpoczęciem sekwencji respawnu.
func play_death() -> void:
	_play_cue(death_cue, _player.character_sprite, _player.global_position, _player)

## Odtwarza właściwą oprawę wyniku próby przeładowania.
func play_reload(succeeded: bool) -> void:
	var cue := reload_cue if succeeded else reload_failed_cue
	_play_cue(cue, _player.character_sprite, _player.global_position, _player)

## Odtwarza dźwięk podniesienia przedmiotu.
func play_item_pickup() -> void:
	_play_cue(item_pickup_cue, null, _player.global_position, _player)

## Odtwarza dźwięk wyrzucenia przedmiotu.
func play_item_drop() -> void:
	_play_cue(item_drop_cue, null, _player.global_position, _player)

## Synchronizuje czas trwania niebieskiej obwódki z cyklem życia efektu mrozu.
func set_freeze_feedback_active(is_active: bool) -> void:
	_active_freeze_effect_count = maxi(
		0,
		_active_freeze_effect_count + (1 if is_active else -1)
	)
	if is_instance_valid(_screen_overlay):
		_screen_overlay.call("set_frozen", _active_freeze_effect_count > 0)

func _play_cue(
	cue: FeedbackCueType,
	animation_target: Node,
	world_position: Vector2,
	sound_emitter: Node2D,
	visual_target: Node2D = null
) -> void:
	if cue == null:
		return
	if visual_target == null:
		visual_target = _player
	GameFeedback.play_cue(cue, animation_target, world_position, sound_emitter, visual_target)

## Reaguje na faktyczne uleczenie: pokazuje zieloną obwódkę TYLKO jeśli uleczono > 0 HP i leczenie nie było ciche/pasywne.
func _on_player_health_healed(amount_restored: int, is_silent: bool) -> void:
	if amount_restored > 0 and not is_silent and is_instance_valid(_screen_overlay):
		_screen_overlay.call("show_healing_feedback")

func _on_player_health_changed(current_health: int, maximum_health: int) -> void:
	_last_known_health = current_health
	if is_instance_valid(_screen_overlay):
		var is_low_health := (
			maximum_health > 0 and float(current_health) / maximum_health <= low_health_ratio
		)
		_screen_overlay.call("set_low_health", is_low_health)

func _get_action_position(cue: FeedbackCueType, target: Node2D) -> Vector2:
	if (
		cue != null
		and cue.visual_origin == VISUAL_ORIGIN_TARGET
		and is_instance_valid(target)
	):
		return target.global_position
	return _player.global_position
