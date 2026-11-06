@abstract
extends Resource
class_name Effect

## Kategorie efektów pozwalające na budowanie odporności (Immunities) zgodnie z zasadą Open/Closed (SOLID).
enum EffectCategory {
	NONE,             ## Brak określonej kategorii (np. efekty techniczne, fabularne)
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
	UTILITY,          ## Efekty specjalne (Niewidzialność, Duch, Nieśmiertelność, Teleport)
	INSTA_KILL        ## Natychmiastowa śmierć
}

@export_group("Podstawowe Informacje")
@export var effect_name : String = "Effect"
@export var effect_color : Color = Color.WHITE
@export var icon : Texture2D
## Kategoria efektu wykorzystywana przez system odporności (LifeStatsComponent).
@export var effect_category : EffectCategory = EffectCategory.NONE

@export_group("Zasady Aplikacji i Wizualizacji")
## Jeśli false, efekt ofensywny NIE zadziała na samego twórcę (source_entity == target).
## Chroni bossów i postacie przed zabiciem samych siebie własnymi plamami kwasu lub wybuchami.
@export var allow_self_inflict : bool = false
## Czy nałożenie tego efektu ma wyzwalać oprawę ekranową/dźwiękową u gracza (np. zielony błysk przy leczeniu)?
@export var show_screen_feedback : bool = true

## Informacje o sprawcy (wstrzykiwane w locie przez broń, pocisk lub umiejętność).
var source_entity: Node2D = null
var source_position: Vector2 = Vector2.ZERO

## Metoda wirtualna do nadpisania przez konkretne efekty.
## Zwraca true, jeśli efekt został pomyślnie nałożony na cel.
func apply_effect(_target : Node2D) -> bool:
	return false

## Zwraca rzeczywistą kategorię efektu w czasie wykonywania gry (odporną na serializację .tres w Godocie).
func get_effective_category() -> EffectCategory:
	return effect_category

## Zwraca true, gdy efekt jest atakiem lub negatywnym statusem blokowanym w strefach pacyfistycznych.
func is_offensive() -> bool:
	return false

## Zwraca true, gdy efekt jest pozytywnym wzmocnieniem lub uleczeniem (zgodnie z zasadą OCP).
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
