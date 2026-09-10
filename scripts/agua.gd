extends Area2D

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

func _on_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D \
		and body.has_method("cambiar_gravedad") \
		and body.has_method("aplicar_damping"):
		body.cambiar_gravedad(true)
		body.aplicar_damping(linear_damp)

	if is_instance_of(body, Danable) and not body.esta_muerto():
		body.recibir_dano(body.vida_maxima)


func _on_body_exited(body: Node2D) -> void:
	if body is CharacterBody2D \
		and body.has_method("cambiar_gravedad") \
		and body.has_method("aplicar_damping"):
		body.cambiar_gravedad(false)
		body.aplicar_damping(0)
