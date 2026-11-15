## Skrypt wstępnie do korekcji pozycji HP bara, może być później rozwinięty o dodatkową funkcjonalność
extends HealthBar

func _physics_process(_delta: float) -> void:
	rotation = -get_parent().rotation

## Paski zdrowia nad głowami jednostek w świecie gry zachowują swój kompaktowy styl lokalny (SOLID - LSP).
func _should_apply_hud_styling() -> bool:
	return false
