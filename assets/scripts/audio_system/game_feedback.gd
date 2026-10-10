class_name GameFeedbackManager
extends Node2D

const SoundEffectType = preload("res://assets/scripts/audio_system/sound_effect.gd")
const VisualEffectType = preload("res://assets/scripts/audio_system/visual_effect.gd")

## Odtwarza przestrzenne i globalne dźwięki oraz jednorazowe efekty wizualne.
## Dostępny w projekcie jako autoload GameFeedback.

## Tworzy efekt wizualny w pozycji świata i zwraca jego instancję.
func play_visual_effect(effect: VisualEffectType, world_position: Vector2) -> Node2D:
	if effect == null:
		push_error("GameFeedback nie może odtworzyć pustego VisualEffect.")
		return null
	if effect.effect_scene == null:
		push_error("GameFeedback: VisualEffect nie ma przypisanej sceny efektu.")
		return null

	var effect_instance := effect.effect_scene.instantiate() as Node2D
	if effect_instance == null:
		push_error("GameFeedback: Root sceny VisualEffect musi dziedziczyć po Node2D.")
		return null

	var effect_parent := _get_effect_parent()
	effect_parent.add_child(effect_instance)
	effect_instance.global_position = world_position + effect.position_offset

	if effect.lifetime_seconds > 0.0:
		_schedule_visual_effect_cleanup(effect_instance, effect.lifetime_seconds)

	return effect_instance

## Odtwarza dźwięk globalnie lub w pozycji emitera 2D.
## Zwraca odtwarzacz (`AudioStreamPlayer` lub `AudioStreamPlayer2D`).
func play_sound(effect: SoundEffectType, emitter: Node2D = null) -> Node:
	if effect == null:
		push_error("GameFeedback nie może odtworzyć pustego SoundEffect.")
		return null
	if effect.audio_stream == null:
		push_error("GameFeedback: SoundEffect nie ma przypisanego AudioStream.")
		return null
	if emitter != null and not is_instance_valid(emitter):
		push_error("GameFeedback: Nie można odtworzyć dźwięku z usuniętego emitera.")
		return null

	var bus_index := AudioServer.get_bus_index(str(effect.bus_name))
	if bus_index < 0:
		push_error("GameFeedback: Nie znaleziono magistrali audio '%s'." % effect.bus_name)
		return null

	if emitter != null and is_instance_valid(emitter):
		var spatial_player := AudioStreamPlayer2D.new()
		spatial_player.max_distance = effect.max_distance
		spatial_player.stream = effect.audio_stream
		spatial_player.bus = str(effect.bus_name)
		spatial_player.volume_db = effect.volume_db
		spatial_player.pitch_scale = _get_pitch_scale(effect)
		add_child(spatial_player)
		spatial_player.global_position = emitter.global_position
		spatial_player.finished.connect(spatial_player.queue_free)
		spatial_player.play()
		return spatial_player

	var player := AudioStreamPlayer.new()
	player.stream = effect.audio_stream
	player.bus = str(effect.bus_name)
	player.volume_db = effect.volume_db
	player.pitch_scale = _get_pitch_scale(effect)
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()
	return player

func _get_effect_parent() -> Node:
	var tree := get_tree()
	if tree != null and is_instance_valid(tree.current_scene):
		return tree.current_scene
	return self

func _schedule_visual_effect_cleanup(effect_instance: Node2D, lifetime_seconds: float) -> void:
	var lifetime_timer := Timer.new()
	lifetime_timer.one_shot = true
	lifetime_timer.wait_time = lifetime_seconds
	effect_instance.add_child(lifetime_timer)
	lifetime_timer.timeout.connect(effect_instance.queue_free)
	lifetime_timer.start()

func _get_pitch_scale(effect: SoundEffectType) -> float:
	return randf_range(
		minf(effect.pitch_min, effect.pitch_max),
		maxf(effect.pitch_min, effect.pitch_max)
	)
