extends Area2D

@export var otro_portal: Area2D

@export_category("Teletransporte")
@export var tiempo_bloqueo_por_cuerpo: float = 0.45

# Guarda el tiempo de desbloqueo de CADA cuerpo.
# Clave: instance_id del cuerpo
# Valor: tiempo en milisegundos
var _bloqueos: Dictionary = {}


# =========================================================
# CUANDO UN CUERPO ENTRA AL PORTAL
# =========================================================

func _on_body_entered(body: Node2D) -> void:

	if not _es_viajero_valido(body):
		return

	if not is_instance_valid(body):
		return

	# Este cuerpo todavía está bloqueado en este portal.
	if _esta_bloqueado(body):
		return

	if otro_portal == null:
		push_warning(
			name + ": No se ha asignado otro_portal."
		)
		return

	if not is_instance_valid(otro_portal):
		push_warning(
			name + ": otro_portal ya no es válido."
		)
		return

	var spawn_point := (
		otro_portal.get_node_or_null("SpawnPoint")
		as Node2D
	)

	if spawn_point == null:
		push_warning(
			otro_portal.name + ": No existe SpawnPoint."
		)
		return


	# =====================================================
	# OBTENER VELOCIDAD
	# =====================================================

	var nueva_velocidad := Vector2.ZERO

	if body is CharacterBody2D:

		var personaje := body as CharacterBody2D

		nueva_velocidad = -personaje.velocity


	# =====================================================
	# BLOQUEAR SOLO A ESTE CUERPO
	# =====================================================

	bloquear_cuerpo(
		body,
		tiempo_bloqueo_por_cuerpo
	)

	# También bloquearlo en el portal destino.
	if otro_portal.has_method("bloquear_cuerpo"):

		otro_portal.call(
			"bloquear_cuerpo",
			body,
			tiempo_bloqueo_por_cuerpo
		)


	# =====================================================
	# TELETRANSPORTE
	# =====================================================

	if body is Danable:
		var viajero := body as Danable
		viajero.aplicar_efecto_portal(
			spawn_point.global_position,
			nueva_velocidad
		)

	elif body.has_method("aplicar_efecto_portal"):
		body.call(
			"aplicar_efecto_portal",
			spawn_point.global_position,
			nueva_velocidad
		)

	else:

		body.global_position = (
			spawn_point.global_position
		)

		if body is CharacterBody2D:

			var personaje := body as CharacterBody2D

			personaje.velocity = nueva_velocidad


# =========================================================
# VALIDAR VIAJERO
# =========================================================

func _es_viajero_valido(body: Node2D) -> bool:

	if body == null:
		return false

	return (
		body.is_in_group("Player")
		or body.is_in_group("player")
		or body.is_in_group("enemy")
	)


# =========================================================
# BLOQUEAR CUERPO
# =========================================================

func bloquear_cuerpo(
	body: Node2D,
	duracion: float
) -> void:

	if body == null:
		return

	if not is_instance_valid(body):
		return

	var id := body.get_instance_id()

	var ahora := Time.get_ticks_msec()

	var nuevo_vencimiento := (
		ahora
		+ int(duracion * 1000.0)
	)

	var vencimiento_actual := int(
		_bloqueos.get(id, 0)
	)

	# Nunca reducir un bloqueo existente.
	_bloqueos[id] = maxi(
		vencimiento_actual,
		nuevo_vencimiento
	)


# =========================================================
# COMPROBAR BLOQUEO
# =========================================================

func _esta_bloqueado(body: Node2D) -> bool:

	if body == null:
		return false

	var id := body.get_instance_id()

	if not _bloqueos.has(id):
		return false

	var vencimiento := int(
		_bloqueos[id]
	)

	var ahora := Time.get_ticks_msec()

	if ahora >= vencimiento:

		_bloqueos.erase(id)

		return false

	return true
