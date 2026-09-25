extends Node

## Zaawansowany, profesjonalny odtwarzacz muzyki z obsługą crossfade'ingu (płynnego przenikania),
## playlist, odstępów czasowych oraz automatycznych zmian ścieżek na podstawie typu pokoju (MapRegionType).
class_name MusicPlayerManager

@export_category("Baza Muzyki (Playlisty)")
## Playlista odtwarzana domyślnie podczas eksploracji świata.
@export var default_playlist: MusicPlaylist
## Playlista odtwarzana, gdy gracz wejdzie do pokoju typu SHOP.
@export var shop_playlist: MusicPlaylist
## Playlista odtwarzana, gdy gracz wejdzie do pokoju typu ARENA.
@export var arena_playlist: MusicPlaylist
## Playlista odtwarzana, gdy gracz wejdzie do pokoju typu BOSS.
@export var boss_playlist: MusicPlaylist
## Playlista odtwarzana w pokoju ze skarbem (TREASURE).
@export var treasure_playlist: MusicPlaylist

@export_category("Ustawienia Globalne")
## Domyślny czas wyciszania przy całkowitym zatrzymaniu muzyki (gdy nie ma nowej playlisty).
@export var default_fade_out_time: float = 2.0

# --- WEWNĘTRZNE KOMPONENTY AUDIO ---
var _player_a: AudioStreamPlayer
var _player_b: AudioStreamPlayer
var _active_player: AudioStreamPlayer
var _crossfade_tween: Tween
var _delay_tween: Tween # <-- Odpowiada za bezpieczne odliczanie odstępu między utworami

# --- STAN PLAYLISTY ---
var _current_playlist: MusicPlaylist = null
var _current_track_stream: AudioStream = null

# --- INTEGRACJA Z SYSTEMEM PAUZY ---
# Utrzymuje kompatybilność z pause_menu.gd bez zmieniania tamtego kodu!
var stream_paused: bool = false:
	set(value):
		stream_paused = value
		if is_instance_valid(_player_a): _player_a.stream_paused = value
		if is_instance_valid(_player_b): _player_b.stream_paused = value

# --- INTEGRACJA Z MAPĄ ---
var _level_manager: Map = null

func _ready() -> void:
	# Odtwarzacz muzyki musi działać nawet po zapauzowaniu gry!
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Inicjalizacja podwójnego silnika odtwarzania (do płynnych przejść)
	_setup_audio_players()
	
	# Podłączenie się do globalnego systemu mapy w celu śledzenia przechodzenia między pokojami
	_try_find_map()
	get_tree().node_added.connect(_on_node_added)
	get_tree().node_removed.connect(_on_node_removed)
	
	# Uruchomienie domyślnej muzyki na start
	if default_playlist:
		play_playlist(default_playlist)

## Tworzy dwa ukryte odtwarzacze dźwięku skierowane na magistralę "Music".
func _setup_audio_players() -> void:
	_player_a = AudioStreamPlayer.new()
	_player_b = AudioStreamPlayer.new()
	
	_player_a.name = "InternalStreamA"
	_player_b.name = "InternalStreamB"
	
	# Przypisujemy do stworzonej przez Ciebie magistrali Music!
	_player_a.bus = "Music"
	_player_b.bus = "Music"
	
	_player_a.volume_db = -80.0 # Całkowita cisza na start
	_player_b.volume_db = -80.0
	
	_player_a.finished.connect(_on_track_finished)
	_player_b.finished.connect(_on_track_finished)
	
	add_child(_player_a)
	add_child(_player_b)
	
	_active_player = _player_a

# ====================================================================
# SYSTEM ZARZĄDZANIA ODTWARZANIEM
# ====================================================================

## Zmienia i rozpoczyna odtwarzanie nowej playlisty. Jeśli to ta sama playlista, ignoruje wezwanie.
func play_playlist(playlist: MusicPlaylist) -> void:
	if playlist == null or playlist.tracks.is_empty():
		stop_music()
		return
		
	# Zabezpieczenie: Jeśli już gramy tę playlistę, nie przerywaj obecnego utworu!
	if _current_playlist == playlist:
		return
		
	# Ubijamy ewentualne oczekiwanie (odstęp) z poprzedniej playlisty
	if _delay_tween and _delay_tween.is_valid():
		_delay_tween.kill()
		
	_current_playlist = playlist
	_current_playlist.prepare_queue()
	
	var first_track = _current_playlist.get_next_track()
	if first_track:
		_crossfade_to(first_track, playlist.transition_duration)

## Płynnie wycisza obecną muzykę i zatrzymuje odtwarzanie.
func stop_music() -> void:
	_current_playlist = null
	_current_track_stream = null
	
	# Przerywamy oczekiwanie na kolejny utwór
	if _delay_tween and _delay_tween.is_valid():
		_delay_tween.kill()
	
	if _crossfade_tween and _crossfade_tween.is_valid():
		_crossfade_tween.kill()
		
	_crossfade_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	if _active_player.playing:
		_crossfade_tween.tween_property(_active_player, "volume_db", -80.0, default_fade_out_time).set_trans(Tween.TRANS_SINE)
		_crossfade_tween.finished.connect(func(): _active_player.stop())

## Funkcja wywoływana automatycznie, gdy utwór dobiegnie końca.
func _on_track_finished() -> void:
	if _current_playlist != null:
		var next_track = _current_playlist.get_next_track()
		if next_track:
			_current_track_stream = next_track
			
			# Obsługa odstępu czasowego między utworami
			if _current_playlist.delay_between_tracks > 0.0:
				if _delay_tween and _delay_tween.is_valid():
					_delay_tween.kill()
					
				_delay_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
				_delay_tween.tween_interval(_current_playlist.delay_between_tracks)
				_delay_tween.finished.connect(func():
					# Upewniamy się, że w trakcie trwania przerwy gracz nie poszedł do innego pokoju (innej playlisty)
					if _current_track_stream == next_track:
						_play_direct(next_track)
				)
			else:
				# Brak odstępu - gramy natychmiast
				_play_direct(next_track)
		else:
			stop_music()

## Wewnętrzna funkcja do twardego odtworzenia utworu (używana m.in. po odstępie czasowym).
func _play_direct(stream: AudioStream) -> void:
	_active_player.stream = stream
	_active_player.volume_db = 0.0 # Domyślna, pełna głośność dla magistrali Music
	_active_player.play()

## Wewnętrzny system płynnego przechodzenia między utworami (Crossfading) ze wsparciem czasu przejścia.
func _crossfade_to(new_stream: AudioStream, fade_time: float) -> void:
	if new_stream == _current_track_stream:
		return
		
	_current_track_stream = new_stream
	var next_player = _player_b if _active_player == _player_a else _player_a
	
	next_player.stream = new_stream
	next_player.volume_db = -80.0
	next_player.play()
	
	if _crossfade_tween and _crossfade_tween.is_valid():
		_crossfade_tween.kill()
		
	_crossfade_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	
	# Wyciszanie obecnie grającego odtwarzacza
	if _active_player.playing:
		if fade_time > 0.0:
			_crossfade_tween.tween_property(_active_player, "volume_db", -80.0, fade_time).set_trans(Tween.TRANS_SINE)
		else:
			_active_player.volume_db = -80.0
		
	# Zgłaśnianie nowego odtwarzacza
	if fade_time > 0.0:
		_crossfade_tween.parallel().tween_property(next_player, "volume_db", 0.0, fade_time).set_trans(Tween.TRANS_SINE)
	else:
		next_player.volume_db = 0.0
	
	# Po zakończeniu przejścia, twardo zatrzymujemy stary silnik i zamieniamy wskaźniki
	_crossfade_tween.finished.connect(func():
		_active_player.stop()
		_active_player = next_player
	)

# ====================================================================
# SYSTEM INTELIGENTNEGO ŚLEDZENIA MAPY
# ====================================================================

func _try_find_map() -> void:
	var map_node = get_tree().get_first_node_in_group("Map")
	if map_node is Map:
		_bind_map(map_node)

func _on_node_added(node: Node) -> void:
	if node is Map:
		_bind_map(node)

func _on_node_removed(node: Node) -> void:
	if node == _level_manager:
		_unbind_map()

func _bind_map(new_map: Map) -> void:
	if _level_manager == new_map:
		return
		
	if _level_manager != null:
		_unbind_map()
		
	_level_manager = new_map
	if not _level_manager.map_region_changed.is_connected(_on_map_region_changed):
		_level_manager.map_region_changed.connect(_on_map_region_changed)
		
	# Natychmiastowa weryfikacja pierwszego pokoju
	if _level_manager.current_map_region:
		_on_map_region_changed(_level_manager.current_map_region)

func _unbind_map() -> void:
	if is_instance_valid(_level_manager) and _level_manager.map_region_changed.is_connected(_on_map_region_changed):
		_level_manager.map_region_changed.disconnect(_on_map_region_changed)
	_level_manager = null

## Automatyczna zmiana muzyki, gdy gracz wchodzi do nowego pokoju!
func _on_map_region_changed(new_map_region: MapRegion) -> void:
	if not is_instance_valid(new_map_region):
		return
		
	match new_map_region.map_region_type:
		MapRegion.MapRegionType.BOSS:
			if boss_playlist: play_playlist(boss_playlist)
			else: play_playlist(default_playlist)
		MapRegion.MapRegionType.SHOP:
			if shop_playlist: play_playlist(shop_playlist)
			else: play_playlist(default_playlist)
		MapRegion.MapRegionType.ARENA:
			if arena_playlist: play_playlist(arena_playlist)
			else: play_playlist(default_playlist)
		MapRegion.MapRegionType.TREASURE:
			if treasure_playlist: play_playlist(treasure_playlist)
			else: play_playlist(default_playlist)
		_:
			# Typy NORMAL, OPEN_WORLD, START, DEV_ROOM
			if default_playlist: play_playlist(default_playlist)
