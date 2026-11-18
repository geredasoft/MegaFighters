extends Area2D


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("Player"):
		return
	if not body is Danable or body.esta_muerto():
		return
	if body.vida_actual * 2 >= body.vida_maxima:
		return

	body.vida_actual = body.vida_maxima
	body.vida_cambiada.emit(body.vida_actual, body.vida_maxima)
	queue_free()
