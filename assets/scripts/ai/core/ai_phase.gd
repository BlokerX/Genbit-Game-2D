extends Resource
class_name AIPhase

@export var phase_name: String = "Phase"
@export_range(0.0, 1.0) var health_threshold: float = 0.5 ## Procent HP (0.5 = 50%), przy którym faza się aktywuje
@export var new_behavior_profile: AIBehaviorProfile ## Opcjonalny nowy profil (zmiana szybkości obrotu, kitingu)
@export var new_abilities: Array[AIAbility] = [] ## Nowa pula ataków (całkowicie zastępuje starą)
@export_range(0.0, 1.0) var heal_percent_on_enter: float = 0.0 ## Leczenie przy wejściu w fazę (np. 0.2 leczy o 20% max HP)
