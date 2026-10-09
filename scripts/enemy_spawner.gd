class_name EnemySpawner
extends Node2D


# =========================================================
# ESCENA DEL ENEMIGO
# =========================================================

const ENEMY_SCENE: PackedScene = preload(
	"res://scenes/enemy.tscn"
)

const EnemyFactoryScript = preload(
	"res://scripts/factories/enemy_factory.gd"
)
const RandomSpawnPointStrategyScript = preload(
	"res://scripts/strategies/random_spawn_point_strategy.gd"
)


# =========================================================
# CONFIGURACIÓN
# =========================================================

@export_category("Enemigos")

@export var cantidad_inicial: int = 5

@export var tiempo_aparicion: float = 3.0

@export var activar_spawn_automatico: bool = false

@export var maximo_enemigos: int = 10

@export var estrategia_puntos: Resource = RandomSpawnPointStrategyScript.new()


# =========================================================
# SEÑALES
# =========================================================

signal enemy_spawned(enemy: Danable)
signal enemy_removed(enemy: Danable)
signal enemies_reset()
signal todos_los_enemigos_derrotados()


# =========================================================
# ESTADO
# =========================================================

var spawn_points: Array[Marker2D] = []

var enemigos_por_spawn: Dictionary = {}

# Todos los enemigos creados durante la partida.
var enemigos_creados: Array[Danable] = []

var enemigos_actuales: int = 0

var nivel_completado: bool = false

var oleada_inicial_creada: bool = false


# =========================================================
# READY
# =========================================================

func _ready() -> void:

	for child: Node in get_children():

		if child is Marker2D:

			var spawn_point: Marker2D = child as Marker2D

			spawn_points.append(spawn_point)


	if spawn_points.is_empty():

		push_warning(
			"EnemySpawner no tiene SpawnPoint."
		)

		return


	crear_enemigos_iniciales.call_deferred()


	if activar_spawn_automatico:

		var timer: Timer = Timer.new()

		timer.wait_time = tiempo_aparicion

		timer.autostart = true

		timer.timeout.connect(spawn_enemy)

		add_child(timer)


# =========================================================
# CREAR ENEMIGOS INICIALES
# =========================================================

func crear_enemigos_iniciales() -> void:

	var cantidad: int = mini(
		cantidad_inicial,
		spawn_points.size()
	)

	for i: int in range(cantidad):

		spawn_enemy()

	oleada_inicial_creada = true
	nivel_completado = false


# =========================================================
# CREAR ENEMIGO
# =========================================================

func spawn_enemy() -> void:

	if enemigos_actuales >= maximo_enemigos:
		return


	var puntos_libres: Array[Marker2D] = []

	for spawn_point: Marker2D in spawn_points:

		if not enemigos_por_spawn.has(spawn_point):

			puntos_libres.append(spawn_point)


	if puntos_libres.is_empty():
		return

	if estrategia_puntos == null or not estrategia_puntos.has_method("seleccionar"):
		push_error("EnemySpawner: estrategia_puntos debe implementar seleccionar().")
		return

	var puntos_seleccionados: Array[Marker2D] = estrategia_puntos.call(
		"seleccionar",
		puntos_libres,
		1
	)
	if puntos_seleccionados.is_empty():
		return

	var spawn_point: Marker2D = puntos_seleccionados.front()

	var enemy: CharacterBody2D = EnemyFactoryScript.crear(ENEMY_SCENE)
	if enemy == null:
		return

	get_tree().current_scene.add_child(enemy)

	enemy.global_position = spawn_point.global_position

	enemigos_por_spawn[spawn_point] = enemy

	enemigos_actuales += 1


	if enemy is Danable:

		var enemigo_danable: Danable = (
			enemy as Danable
		)

		# Guardamos TODOS los enemigos creados.
		enemigos_creados.append(
			enemigo_danable
		)


		if not enemigo_danable.murio.is_connected(
			_on_enemigo_murio.bind(enemigo_danable)
		):

			enemigo_danable.murio.connect(
				_on_enemigo_murio.bind(enemigo_danable)
			)


		enemy_spawned.emit(
			enemigo_danable
		)


# =========================================================
# ENEMIGO MURIÓ
# =========================================================

func _on_enemigo_murio(enemy: Danable) -> void:

	if enemy == null:
		return

	if not is_instance_valid(enemy):
		return


	var spawn_point_encontrado: Marker2D = null


	for spawn_point: Marker2D in enemigos_por_spawn.keys():

		if enemigos_por_spawn[spawn_point] == enemy:

			spawn_point_encontrado = spawn_point

			break


	if spawn_point_encontrado == null:
		return


	enemigos_por_spawn.erase(
		spawn_point_encontrado
	)

	enemigos_actuales = max(
		enemigos_actuales - 1,
		0
	)


	print(
		"💀 Enemy derrotado: ",
		enemy.name
	)

	print(
		"👾 Enemigos restantes: ",
		enemigos_actuales
	)


	enemy_removed.emit(
		enemy
	)


	if (
		oleada_inicial_creada
		and enemigos_actuales == 0
		and not nivel_completado
	):

		nivel_completado = true

		print("========================================")
		print("🏆 NIVEL 1 COMPLETADO")
		print("========================================")

		todos_los_enemigos_derrotados.emit()


# =========================================================
# REINICIAR
# =========================================================

func reiniciar() -> void:

	print("🔄 EnemySpawner: reiniciando...")


	nivel_completado = false
	oleada_inicial_creada = false


	# Avisamos a la UI para limpiar las barras.
	enemies_reset.emit()


	# =====================================================
	# ELIMINAR TODOS LOS ENEMIGOS CREADOS
	# =====================================================

	for enemy: Danable in enemigos_creados:

		if is_instance_valid(enemy):

			enemy.queue_free()


	# Limpiar las referencias.
	enemigos_creados.clear()

	enemigos_por_spawn.clear()

	enemigos_actuales = 0


	# Esperar a que Godot procese los queue_free().
	await get_tree().process_frame


	# Crear nuevamente la oleada inicial.
	crear_enemigos_iniciales()


	print("✅ EnemySpawner reiniciado")
