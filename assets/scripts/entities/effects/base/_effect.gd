@abstract
extends Resource
class_name Effect
## Abstrakcyjna klasa bazowa dla wszystkich efektów natychmiastowych, czasowych i użytkowych w grze.

## Główne kategorie domenowe/żywiołowe efektów (dla szczegółowych klas efektów używaj target_effect_script w EffectProtectionRule - OCP).
enum EffectCategory {
	NONE,             ## Brak określonej kategorii
	PHYSICAL_DAMAGE,  ## Obrażenia fizyczne / bezpośrednie
	POISON_ACID,      ## Trucizny, kwas, obrażenia chemiczne w czasie
	FIRE_BURN,        ## Ogień i podpalenia
	FROST_FREEZE,     ## Mróz i całkowite zamrożenie
	RADIATION,        ## Promieniowanie (np. Gamma Burst)
	MENTAL_PSYCHOSIS, ## Ataki psychiczne i dezorientacja
	STUN,             ## Ogłuszenie (blokada ataku)
	KNOCKBACK,        ## Fizyczny odrzut
	SLOW,             ## Spowolnienie ruchu
	STAT_BUFF,        ## Pozytywne wzmocnienia statystyk
	STAT_DEBUFF,      ## Negatywne osłabienia statystyk
	HEAL,             ## Leczenie i regeneracja
	UTILITY,          ## Efekty użytkowe (Duch, Niewidzialność, Nieśmiertelność, Teleport)
	INSTA_KILL        ## Natychmiastowa śmierć
}

## Centralny słownik czytelnych nazw kategorii domenowych dla UI i Tooltipów (Information Expert / DRY).
const CATEGORY_DISPLAY_NAMES: Dictionary = {
	EffectCategory.NONE: "Efekt",
	EffectCategory.PHYSICAL_DAMAGE: "Obrażenia fizyczne",
	EffectCategory.POISON_ACID: "Trucizna i Kwas",
	EffectCategory.FIRE_BURN: "Ogień i Podpalenie",
	EffectCategory.FROST_FREEZE: "Mróz i Zamrożenie",
	EffectCategory.RADIATION: "Promieniowanie",
	EffectCategory.MENTAL_PSYCHOSIS: "Psychoza",
	EffectCategory.STUN: "Ogłuszenie (Stun)",
	EffectCategory.KNOCKBACK: "Odrzut (Knockback)",
	EffectCategory.SLOW: "Spowolnienie",
	EffectCategory.STAT_BUFF: "Wzmocnienia statystyk",
	EffectCategory.STAT_DEBUFF: "Osłabienia statystyk",
	EffectCategory.HEAL: "Leczenie i Regeneracja",
	EffectCategory.UTILITY: "Efekty użytkowe",
	EffectCategory.INSTA_KILL: "Natychmiastowa śmierć"
}

@export_group("Podstawowe Informacje")
## Unikalna nazwa efektu wyświetlana w interfejsie oraz używana do identyfikacji statusu.
@export var effect_name : String = "Effect"
## Kolor tekstu i ikony efektu na pasku aktywnych statusów HUD.
@export var effect_color : Color = Color.WHITE
## Ikona wyświetlana obok nazwy efektu na HUD-zie gracza.
@export var icon : Texture2D
## Kategoria domenowa efektu wykorzystywana przez system odporności (LifeStatsComponent oraz ProtectiveItemComponent).
@export var effect_category : EffectCategory = EffectCategory.NONE
## Otwarta lista tagów efektu (np. &"speed", &"acid", &"curse") pozwalająca grupować efekty w Inspektorze bez edycji kodu (OCP).
@export var effect_tags : Array[StringName] = []

@export_group("Zasady Aplikacji i Wizualizacji")
## Jeśli false, efekt ofensywny NIE zadziała na samego twórcę (source_entity == target).
@export var allow_self_inflict : bool = false
## Czy nałożenie tego efektu ma wyzwalać oprawę ekranową u gracza (np. zielony błysk przy leczeniu)?
@export var show_screen_feedback : bool = true

## Informacje o sprawcy (wstrzykiwane w locie przez broń, pocisk lub umiejętność).
var source_entity: Node2D = null
var source_position: Vector2 = Vector2.ZERO

## Zwraca czytelną dla gracza nazwę podanej kategorii efektu (Information Expert).
static func get_category_display_name(category: EffectCategory) -> String:
	return CATEGORY_DISPLAY_NAMES.get(category, "Efekt")

## Metoda wirtualna do nadpisania przez konkretne efekty.
func apply_effect(_target : Node2D) -> bool:
	return false

## Skaluje czas trwania efektu przez podany mnożnik (metoda polimorficzna dla ProtectiveItemComponent - OCP).
func apply_duration_multiplier(_multiplier: float) -> void:
	pass

## Skaluje siłę oddziaływania efektu przez podany mnożnik (metoda polimorficzna dla ProtectiveItemComponent - OCP).
func apply_potency_multiplier(_multiplier: float) -> void:
	pass

## Zwraca true, jeśli wiele instancji tego efektu z różnych przedmiotów (np. Spodnie +20 Armor i Buty +20 Armor) powinno się sumować.
func can_stack_passive_instances() -> bool:
	return true

## Zwraca podstawową kategorię efektu w czasie wykonywania gry.
func get_effective_category() -> EffectCategory:
	return effect_category

## Sprawdza, czy ten efekt należy do podanej kategorii domenowej.
func matches_category(expected_category: EffectCategory) -> bool:
	if expected_category == EffectCategory.NONE:
		return false
	return int(get_effective_category()) == int(expected_category)

## Zwraca true, gdy efekt jest atakiem lub negatywnym statusem blokowanym w strefach pacyfistycznych.
func is_offensive() -> bool:
	return false

## Zwraca true, gdy efekt jest pozytywnym wzmocnieniem lub uleczeniem.
func is_beneficial() -> bool:
	if is_offensive():
		return false
	return get_effective_category() in [
		EffectCategory.HEAL,
		EffectCategory.STAT_BUFF,
		EffectCategory.UTILITY
	]

## Sprawdza, czy efekt pochodzi ze źródła pasywnego (zbroja, plecak), aury pokoju lub ma wyłączony feedback.
func is_silent_or_passive() -> bool:
	if not show_screen_feedback:
		return true
	if has_meta("passive_source") or (has_meta("is_environment_aura") and get_meta("is_environment_aura") == true):
		return true
	return false

## Sprawdza, czy efekt posiada przypisany tag w tablicy effect_tags (bez rozróżniania wielkości liter).
func has_effect_tag(tag: StringName) -> bool:
	if tag == &"" or effect_tags.is_empty():
		return false
	if effect_tags.has(tag):
		return true
	var expected_lower: String = String(tag).to_lower().strip_edges()
	for existing_tag in effect_tags:
		if String(existing_tag).to_lower().strip_edges() == expected_lower:
			return true
	return false
