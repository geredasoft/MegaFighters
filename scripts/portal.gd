extends Area2D

@export var otro_portal: Area2D

@export_category("Teletransporte")
@export var tiempo_bloqueo_por_cuerpo: float = 0.45

# Guarda el tiempo de desbloqueo de CADA cuerpo.
# Clave: instance_id del cuerpo
# Valor: tiempo en milisegundos
var _bloqueos: Dictionary = {}
var _posiciones_previas: Dictionary = {}

# El área física puede no emitir body_entered si un cuerpo cruza toda su
# anchura entre dos pasos de física. Esta tolerancia cubre el tamaño del actor.
@export_category("Detección")
@export var margen_deteccion: Vector2 = Vector2(12.0, 8.0)
@export var distancia_muestreo: float = 4.0


func _physics_process(_delta: float) -> void:
	var viajeros_vistos: Dictionary = {}
	var forma := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if forma == null or forma.shape == null or forma.disabled:
		return

	var limites := forma.shape.get_rect().grow_individual(
		margen_deteccion.x,
		margen_deteccion.y,
		margen_deteccion.x,
		margen_deteccion.y
	)

	for grupo in ["Player", "player", "enemy"]:
		for candidato in get_tree().get_nodes_in_group(grupo):
			if not candidato is Node2D or not is_instance_valid(candidato):
				continue
			var viajero := candidato as Node2D
			var id := viajero.get_instance_id()
			viajeros_vistos[id] = true
			var posicion_actual := forma.to_local(viajero.global_position)
			if _posiciones_previas.has(id):
				var posicion_previa: Vector2 = _posiciones_previas[id]
				if _segmento_interseca_rectangulo(posicion_previa, posicion_actual, limites):
					_teletransportar(viajero)
			else:
				# Captura actores que aparezcan ya dentro del área.
				if limites.has_point(posicion_actual):
					_teletransportar(viajero)
			if is_instance_valid(viajero):
				_posiciones_previas[id] = forma.to_local(viajero.global_position)

	for id in _posiciones_previas.keys():
		if not viajeros_vistos.has(id):
			_posiciones_previas.erase(id)


func _segmento_interseca_rectangulo(origen: Vector2, destino: Vector2, limites: Rect2) -> bool:
	var distancia := origen.distance_to(destino)
	var pasos := maxi(1, ceili(distancia / maxf(distancia_muestreo, 1.0)))
	for indice in range(pasos + 1):
		var punto := origen.lerp(destino, float(indice) / float(pasos))
		if limites.has_point(punto):
			return true
	return false


# =========================================================
# CUANDO UN CUERPO ENTRA AL PORTAL
# =========================================================

func _on_body_entered(body: Node2D) -> void:
	_teletransportar(body)


func _teletransportar(body: Node2D) -> void:

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
		minf(tiempo_bloqueo_por_cuerpo, 0.08)
	)

	# También bloquearlo en el portal destino.
	if otro_portal.has_method("bloquear_cuerpo"):

		otro_portal.call(
			"bloquear_cuerpo",
			body,
			minf(tiempo_bloqueo_por_cuerpo, 0.08)
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
