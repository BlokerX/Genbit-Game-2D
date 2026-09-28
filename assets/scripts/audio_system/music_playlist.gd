extends Resource
class_name MusicPlaylist

## Klasa przechowująca dane o liście odtwarzania muzyki w grze.
## Pozwala na grupowanie utworów (np. "Muzyka Tła", "Walka z Bossem") i zarządzanie ich odtwarzaniem.

@export_group("Ustawienia Playlisty")
## Nazwa playlisty (wyłącznie w celach organizacyjnych).
@export var playlist_name: String = "Nowa Playlista"

## Lista utworów dźwiękowych (.ogg, .mp3, .wav) przypisanych do tej playlisty.
@export var tracks: Array[AudioStream] = []

@export_group("Zachowanie")
## Czy po zakończeniu ostatniego utworu, playlista ma zacząć grać od nowa?
@export var loop: bool = true

## Czy utwory mają być odtwarzane w losowej kolejności?
@export var shuffle: bool = false

@export_group("Odstępy i Przejścia")
## Czas (w sekundach) płynnego przenikania (crossfade), gdy gra wchodzi na tę playlistę (np. 2.0s dla ambientu, 0.1s dla Bossa).
@export var transition_duration: float = 0

## Czas ciszy (w sekundach) pomiędzy zakończeniem jednego utworu a startem kolejnego W TEJ playliście.
@export var delay_between_tracks: float = 0.0

# Wewnętrzna kopia do tasowania, aby nie psuć oryginalnej kolejności z Inspektora
var _playback_queue: Array[AudioStream] = []

## Inicjalizuje i przygotowuje kolejkę odtwarzania.
func prepare_queue() -> void:
	_playback_queue = tracks.duplicate()
	if shuffle:
		_playback_queue.shuffle()

## Zwraca kolejny utwór z kolejki. Zwraca null, jeśli playlista się skończyła i nie loopuje.
func get_next_track() -> AudioStream:
	if _playback_queue.is_empty():
		if loop and not tracks.is_empty():
			prepare_queue() # Odnawiamy kolejkę, jeśli loop jest włączony
		else:
			return null
			
	return _playback_queue.pop_front()
