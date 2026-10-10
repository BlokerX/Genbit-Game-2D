class_name GameFeedbackManager
extends Node2D

const SoundEffectType = preload("res://assets/scripts/audio_system/sound_effect.gd")
const VisualEffectType = preload("res://assets/scripts/audio_system/visual_effect.gd")
const AnimationEffectType = preload("res://assets/scripts/audio_system/animation_effect.gd")
const FeedbackCueType = preload("res://assets/scripts/audio_system/feedback_cue.gd")

## Odtwarza animacje, dźwięki przestrzenne i globalne oraz jednorazowe efekty wizualne.
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

	var bus_index := AudioServer.get_bus_index(effect.bus_name)
	if bus_index < 0:
		push_error("GameFeedback: Nie znaleziono magistrali audio '%s'." % effect.bus_name)
		return null

	if emitter != null and is_instance_valid(emitter):
		var spatial_player := AudioStreamPlayer2D.new()
		spatial_player.max_distance = effect.max_distance
		spatial_player.stream = effect.audio_stream
		spatial_player.bus = effect.bus_name
		spatial_player.volume_db = effect.volume_db
		spatial_player.pitch_scale = _get_pitch_scale(effect)
		add_child(spatial_player)
		spatial_player.global_position = emitter.global_position
		spatial_player.finished.connect(spatial_player.queue_free)
		spatial_player.play()
		return spatial_player

	var player := AudioStreamPlayer.new()
	player.stream = effect.audio_stream
	player.bus = effect.bus_name
	player.volume_db = effect.volume_db
	player.pitch_scale = _get_pitch_scale(effect)
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()
	return player

## Odtwarza istniejącą animację w AnimationPlayer albo AnimatedSprite2D.
func play_animation(effect: AnimationEffectType, animation_target: Node) -> bool:
	if effect == null:
		push_error("GameFeedback nie może odtworzyć pustego AnimationEffect.")
		return false
	if not is_instance_valid(animation_target):
		push_error("GameFeedback: Nieprawidłowy węzeł docelowy animacji.")
		return false
	if effect.animation_name.is_empty():
		push_error("GameFeedback: AnimationEffect nie ma ustawionej nazwy animacji.")
		return false

	if animation_target is AnimationPlayer:
		var animation_player := animation_target as AnimationPlayer
		if not animation_player.has_animation(effect.animation_name):
			push_error(
				"GameFeedback: AnimationPlayer nie ma animacji '%s'."
				% effect.animation_name
			)
			return false
		animation_player.play(
			effect.animation_name,
			effect.blend_time,
			effect.playback_speed,
			effect.from_end
		)
		return true

	if animation_target is AnimatedSprite2D:
		var animated_sprite := animation_target as AnimatedSprite2D
		if (
			animated_sprite.sprite_frames == null
			or not animated_sprite.sprite_frames.has_animation(effect.animation_name)
		):
			push_error(
				"GameFeedback: AnimatedSprite2D nie ma animacji '%s'."
				% effect.animation_name
			)
			return false
		animated_sprite.play(effect.animation_name, effect.playback_speed, effect.from_end)
		return true

	push_error(
		"GameFeedback: Animacje są obsługiwane przez AnimationPlayer lub AnimatedSprite2D."
	)
	return false

## Odtwarza razem animację, efekt wizualny i dźwięk przypisane do jednej akcji.
func play_cue(
	cue: FeedbackCueType,
	animation_target: Node = null,
	world_position: Vector2 = Vector2.ZERO,
	sound_emitter: Node2D = null
) -> bool:
	if cue == null:
		push_error("GameFeedback nie może odtworzyć pustego FeedbackCue.")
		return false

	var played_any := false
	var succeeded := true
	if cue.animation_effect != null:
		if animation_target == null:
			push_error("GameFeedback: FeedbackCue wymaga węzła docelowego animacji.")
			succeeded = false
		elif play_animation(cue.animation_effect, animation_target):
			played_any = true
		else:
			succeeded = false

	if cue.visual_effect != null:
		if play_visual_effect(cue.visual_effect, world_position) != null:
			played_any = true
		else:
			succeeded = false

	if cue.sound_effect != null:
		if play_sound(cue.sound_effect, sound_emitter) != null:
			played_any = true
		else:
			succeeded = false

	if not played_any and succeeded:
		push_warning("GameFeedback: FeedbackCue nie zawiera żadnego efektu.")
		return false
	return succeeded and played_any

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
