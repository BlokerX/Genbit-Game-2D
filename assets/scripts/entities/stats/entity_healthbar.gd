## Skrypt wstępnie do korekcji pozycji HP bara, może być później rozwinięty o dodatkową funkcjonalność
## Btw nie wiem gdzie dać ten skrypt. Zapraszam do zmian w razie czego
extends ProgressBar

func _physics_process(delta: float) -> void:
	rotation = -get_parent().rotation
