extends Node
class_name CombatCamera

## Cámara lateral con encuadre reactivo para las escenas de combate.

@export var zoom_base := Vector2(0.9, 0.9)
@export var zoom_combate := Vector2(0.78, 0.78)
@export var zoom_cercano := Vector2(1.04, 1.04)
@export var velocidad_seguimiento := 4.5
@export var velocidad_zoom := 2.2
@export var distancia_encuadre := 430.0

var _jugador: Danable
var _spawner: EnemySpawner
var _camera: Camera2D
var _pulso_zoom := 0.0
var _objetivo_zoom := Vector2.ONE
var _objetivo_posicion := Vector2.ZERO
var _enemigos: Array[Danable] = []


func configurar(jugador: Danable, spawner: EnemySpawner) -> void:
	_jugador = jugador
	_spawner = spawner


func _ready() -> void:
	_camera = Camera2D.new()
	_camera.name = "CombatCamera2D"
	_camera.position_smoothing_enabled = true
	_camera.position_smoothing_speed = velocidad_seguimiento
	_camera.zoom = zoom_base
	_camera.limit_left = 0
	_camera.limit_top = 0
	_camera.limit_right = 1152
	_camera.limit_bottom = 648
	add_child(_camera)
	_camera.make_current()

	if is_instance_valid(_jugador):
		_jugador.vida_cambiada.connect(_al_cambiar_vida)
		_objetivo_posicion = _jugador.global_position
	if is_instance_valid(_spawner):
		_spawner.enemy_spawned.connect(_al_aparecer_enemigo)
		_spawner.enemy_removed.connect(_al_eliminar_enemigo)
		for enemigo in _spawner.enemigos_creados:
			_al_aparecer_enemigo(enemigo)


func _process(delta: float) -> void:
	if not is_instance_valid(_jugador):
		return

	_actualizar_encuadre()
	_camera.global_position = _camera.global_position.lerp(
		_objetivo_posicion,
		1.0 - exp(-velocidad_seguimiento * delta)
	)

	_pulso_zoom = move_toward(_pulso_zoom, 0.0, delta * 1.8)
	var zoom_final := _objetivo_zoom + Vector2.ONE * _pulso_zoom
	_camera.zoom = _camera.zoom.lerp(
		zoom_final,
		1.0 - exp(-velocidad_zoom * delta)
	)


func _actualizar_encuadre() -> void:
	var jugador_pos := _jugador.global_position
	var enemigo_cercano: Danable
	var distancia := distancia_encuadre
	var enemigos_vivos := 0

	for enemigo in _enemigos:
		if not is_instance_valid(enemigo) or enemigo.esta_muerto():
			continue
		enemigos_vivos += 1
		var distancia_actual := jugador_pos.distance_to(enemigo.global_position)
		if distancia_actual < distancia:
			distancia = distancia_actual
			enemigo_cercano = enemigo

	_objetivo_posicion = jugador_pos
	_objetivo_zoom = zoom_base
	if is_instance_valid(enemigo_cercano):
		# El jugador conserva más peso para que la cámara no salte entre rivales.
		var factor := clampf(1.0 - distancia / distancia_encuadre, 0.0, 1.0)
		_objetivo_posicion = jugador_pos.lerp(enemigo_cercano.global_position, 0.28 * factor)
		_objetivo_zoom = zoom_base.lerp(zoom_cercano, factor * 0.65)
	if enemigos_vivos >= 3:
		_objetivo_zoom = _objetivo_zoom.lerp(zoom_combate, 0.45)


func _al_aparecer_enemigo(enemigo: Danable) -> void:
	if is_instance_valid(enemigo) and not _enemigos.has(enemigo):
		_enemigos.append(enemigo)


func _al_eliminar_enemigo(enemigo: Danable) -> void:
	_enemigos.erase(enemigo)
	_pulso_zoom = maxf(_pulso_zoom, 0.12)


func _al_cambiar_vida(actual: int, maxima: int) -> void:
	if actual < maxima:
		_pulso_zoom = maxf(_pulso_zoom, 0.16)
