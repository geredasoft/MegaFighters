extends Area2D

@export var otro_portal: Area2D

# Variable para bloquear este portal específico por unos milisegundos tras usarlo
var _en_cooldown := false

func _on_body_entered(body: Node2D) -> void:
	if _en_cooldown:
		return

	var es_viajero := body.is_in_group("player") or body.is_in_group("Player") or body.is_in_group("enemy")
	if not es_viajero:
		return

	if otro_portal == null:
		push_warning(name + ": No se ha asignado otro_portal.")
		return

	var spawn_point := otro_portal.get_node_or_null("SpawnPoint") as Node2D
	if spawn_point == null:
		push_warning(otro_portal.name + ": No existe SpawnPoint.")
		return

	var nueva_velocidad := Vector2.ZERO
	if body is CharacterBody2D:
		nueva_velocidad = -body.velocity

	# 1. Poner en cooldown al portal de DESTINO para que no te devuelva al entrar
	otro_portal.activar_cooldown(0.3)

	# 2. Teletransportar
	if body.has_method("aplicar_efecto_portal"):
		body.aplicar_efecto_portal(spawn_point.global_position, nueva_velocidad)
	else:
		body.global_position = spawn_point.global_position
		if body is CharacterBody2D:
			body.velocity = nueva_velocidad


func activar_cooldown(tiempo: float) -> void:
	_en_cooldown = true
	await get_tree().create_timer(tiempo).timeout
	_en_cooldown = false


# Ya no necesitamos _on_body_exited para limpiar nada complejo
func _on_body_exited(body: Node2D) -> void:
	pass
