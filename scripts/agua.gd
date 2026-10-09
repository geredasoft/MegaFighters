extends Area2D

func _on_body_entered(body: Node2D) -> void:
	if body is Danable:
		var personaje := body as Danable
		personaje.cambiar_gravedad(true)
		personaje.aplicar_damping(linear_damp)
		if not personaje.esta_muerto():
			personaje.recibir_dano(personaje.vida_maxima)
		return

	if body is CharacterBody2D \
		and body.has_method("cambiar_gravedad") \
		and body.has_method("aplicar_damping"):
		body.call("cambiar_gravedad", true)
		body.call("aplicar_damping", linear_damp)


func _on_body_exited(body: Node2D) -> void:
	if body is Danable:
		var personaje := body as Danable
		personaje.cambiar_gravedad(false)
		personaje.aplicar_damping(0)
		return

	if body is CharacterBody2D \
		and body.has_method("cambiar_gravedad") \
		and body.has_method("aplicar_damping"):
		body.call("cambiar_gravedad", false)
		body.call("aplicar_damping", 0)
