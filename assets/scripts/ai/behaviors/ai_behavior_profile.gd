## Zasób (Resource) przechowujący "osobowość" i parametry fizyczne sztucznej inteligencji. 
## Możesz tworzyć różne pliki .tres (np. spider_profile.tres, sniper_profile.tres) 
## i podpinać je do węzła AIController wroga, aby natychmiast zmienić jego zachowanie.
extends Resource
class_name AIBehaviorProfile

@export_category("Percepcja i Dystans")

## Promień (w pikselach), w obrębie którego zmysły wroga (PerceptionComponent) mogą wykryć cel.
## Uwaga: Wzrok wciąż jest blokowany przez ściany (LineOfSight).
@export var detection_distance: float = 600.0

## Dystans od celu, przy którym AI przestaje iść naprzód (kończy pościg/ruch).
## BARDZO WAŻNE: Wartość ta MUSI być równa lub mniejsza niż zasięg ataku broni (Max Range w pliku np. gun.tres), 
## w przeciwnym razie potwór zatrzyma się i nie będzie w stanie zaatakować.
@export var min_stopping_distance: float = 30.0
## Jeśli gracz znajdzie się bliżej niż ten dystans, wróg zacznie uciekać tyłem (kiting).
## Ustaw na 0.0, jeśli potwór ma nigdy nie uciekać (np. Pająk walczący wręcz).
@export var retreat_distance: float = 0.0

@export_category("Poruszanie")

## Jeśli włączone, wróg będzie płynnie i fizycznie obracał swój węzeł w stronę celu (jak wskazówka zegara). 
## Włącz dla gier Top-Down (np. Hotline Miami). 
## Wyłącz dla rzutów izometrycznych lub side-scrollerów, gdzie obrót załatwia zmiana klatek animacji.
@export var can_rotate_to_target: bool = true 

## Szybkość płynnego obracania się w stronę celu (używane tylko, jeśli 'can_rotate_to_target' jest włączone).
@export var rotation_speed: float = 5.0

## Maksymalny promień (w pikselach) od punktu startowego, po którym przeciwnik 
## będzie losowo wędrował w stanie swobodnym (Idle) lub szukania (Search).
@export var wander_radius: float = 150.0

## Minimalny czas (w sekundach), przez jaki wróg będzie stał w miejscu, 
## zanim podejmie kolejny losowy krok podczas wędrówki.
@export var wander_interval_min: float = 1.0

## Maksymalny czas (w sekundach), przez jaki wróg będzie stał w miejscu, 
## zanim podejmie kolejny losowy krok podczas wędrówki.
@export var wander_interval_max: float = 6.0

@export_category("Walka i Wybór Broni")
## Dystans, poniżej którego AI schowa broń palną i wyciągnie broń białą (np. nóż).
@export var melee_switch_distance: float = 60.0
