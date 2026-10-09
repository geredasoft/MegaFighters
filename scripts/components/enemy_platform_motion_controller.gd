extends RefCounted

var _agente: CharacterBody2D
var _sprite: AnimatedSprite2D
var _controlador_decision
var _actualizar_hitbox: Callable
var _actualizar_animacion: Callable
var _reproducir_animacion: Callable


func _init(
	agente: CharacterBody2D,
	sprite: AnimatedSprite2D,
	controlador_decision,
	actualizar_hitbox: Callable,
	actualizar_animacion: Callable,
	reproducir_animacion: Callable
) -> void:
	_agente = agente
	_sprite = sprite
	_controlador_decision = controlador_decision
	_actualizar_hitbox = actualizar_hitbox
	_actualizar_animacion = actualizar_animacion
	_reproducir_animacion = reproducir_animacion


func ejecutar_intercepcion(
	plataforma: AnimatableBody2D,
	delta: float,
	fuerza_salto: float,
	velocidad_carrera: float,
	velocidad_trote: float,
	aceleracion: float
) -> void:
	var decision: Dictionary = _controlador_decision.call(
		"decidir_maniobra_intercepcion",
		plataforma,
		fuerza_salto,
		velocidad_carrera,
		velocidad_trote
	)
	var direccion_x: float = float(decision["direccion"])
	var velocidad_objetivo: float = float(decision["velocidad_objetivo"])

	if not is_zero_approx(direccion_x):
		_sprite.flip_h = direccion_x < 0.0
		_actualizar_hitbox.call()

	if bool(decision["debe_saltar"]):
		_agente.velocity.y = float(decision["impulso_salto"])
		_agente.velocity.x = direccion_x * velocidad_carrera
		_reproducir_animacion.call("jump")
		return

	_agente.velocity.x = move_toward(
		_agente.velocity.x,
		direccion_x * velocidad_objetivo,
		aceleracion * delta
	)
	_actualizar_animacion.call(velocidad_objetivo == velocidad_carrera)


func ejecutar_en_plataforma(
	velocidad_plataforma: Vector2,
	direcciones_desembarco: Array[float],
	delta: float,
	alcance: float,
	profundidad: float,
	alcance_salto: float,
	profundidad_salto: float,
	fuerza_salto: float,
	velocidad_carrera: float,
	desaceleracion: float
) -> bool:
	var decision: Dictionary = _controlador_decision.call(
		"seleccionar_desembarco",
		direcciones_desembarco,
		alcance,
		profundidad,
		alcance_salto,
		profundidad_salto
	)
	var encontrado: bool = bool(decision["encontrado"])
	var direccion: float = float(decision["direccion"])
	var necesita_salto: bool = bool(decision["necesita_salto"])

	if _agente.is_on_floor() and encontrado:
		_sprite.flip_h = direccion < 0.0
		_actualizar_hitbox.call()

		if necesita_salto:
			_agente.velocity.y = fuerza_salto * 0.85
			_agente.velocity.x = (
				direccion * velocidad_carrera
				+ velocidad_plataforma.x
			)
			_reproducir_animacion.call("jump")
		else:
			_agente.velocity.x = (
				direccion * velocidad_carrera
				+ velocidad_plataforma.x
			)
			_actualizar_animacion.call(true)

		return true

	if _agente.is_on_floor():
		_agente.velocity.x = move_toward(
			_agente.velocity.x,
			velocidad_plataforma.x,
			desaceleracion * delta
		)
		_reproducir_animacion.call("standing")
	else:
		_actualizar_animacion.call(false)

	return false
