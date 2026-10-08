class_name EnemySpawner
extends Node2D


# =========================================================
# ESCENA DEL ENEMIGO
# =========================================================

const ENEMY_SCENE: PackedScene = preload(
	"res://scenes/enemy.tscn"
)


# =========================================================
# CONFIGURACIÓN
# =========================================================

@export_category("Enemigos")

@export var cantidad_inicial: int = 5

@export var tiempo_aparicion: float = 3.0

@export var activar_spawn_automatico: bool = false

@export var maximo_enemigos: int = 10

# =========================================================
# SEÑALES
# =========================================================

signal enemy_spawned(enemy: Danable)
signal enemy_removed(enemy: Danable)
signal enemies_reset()

# =========================================================
# ESTADO
# =========================================================

var spawn_points: Array[Marker2D] = []

# Guarda qué SpawnPoint está ocupado por cada enemigo
var enemigos_por_spawn: Dictionary = {}

var enemigos_actuales: int = 0

var reiniciador = Reiniciador.new(reiniciar)

var velocidad_knockback: float = 0.0

# =========================================================
# READY
# =========================================================

func _ready() -> void:

	# =====================================================
	# BUSCAR SPAWN POINTS
	# =====================================================

	for child: Node in get_children():

		if child is Marker2D:

			var spawn_point: Marker2D = child as Marker2D

			spawn_points.append(spawn_point)


	# =====================================================
	# COMPROBAR SPAWN POINTS
	# =====================================================

	if spawn_points.is_empty():

		push_warning(
			"EnemySpawner no tiene SpawnPoint."
		)

		return


	# =====================================================
	# SPAWN INICIAL DIFERIDO
	# =====================================================

	crear_enemigos_iniciales.call_deferred()


	# =====================================================
	# SPAWN AUTOMÁTICO
	# =====================================================

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


# =========================================================
# CREAR ENEMIGO
# =========================================================

func spawn_enemy() -> void:

	# =====================================================
	# COMPROBAR LÍMITE GLOBAL
	# =====================================================

	if enemigos_actuales >= maximo_enemigos:

		return


	# =====================================================
	# BUSCAR SPAWN POINTS LIBRES
	# =====================================================

	var puntos_libres: Array[Marker2D] = []

	for spawn_point: Marker2D in spawn_points:

		if not enemigos_por_spawn.has(spawn_point):

			puntos_libres.append(spawn_point)


	# =====================================================
	# NO HAY PUNTOS LIBRES
	# =====================================================

	if puntos_libres.is_empty():

		return


	# =====================================================
	# ELEGIR PUNTO LIBRE ALEATORIO
	# =====================================================

	var spawn_point: Marker2D = puntos_libres.pick_random()


	# =====================================================
	# CREAR ENEMIGO
	# =====================================================

	var enemy_node: Node = ENEMY_SCENE.instantiate()


	# =====================================================
	# COMPROBAR TIPO
	# =====================================================

	if not enemy_node is CharacterBody2D:

		push_error(
			"enemy.tscn debe tener CharacterBody2D como nodo raíz."
		)

		enemy_node.queue_free()

		return


	var enemy: CharacterBody2D = (
		enemy_node as CharacterBody2D
	)


	# =====================================================
	# AGREGAR A LA ESCENA
	# =====================================================

	get_tree().current_scene.add_child(enemy)


	# =====================================================
	# POSICIÓN
	# =====================================================

	enemy.global_position = spawn_point.global_position


	enemigos_por_spawn[spawn_point] = enemy
	enemigos_actuales += 1

	enemy.tree_exited.connect(
		_on_enemy_tree_exited.bind(spawn_point, enemy)
	)

	enemy_spawned.emit(enemy as Danable)

# =========================================================
# ENEMIGO ELIMINADO
# =========================================================

func _on_enemy_tree_exited(
	spawn_point: Marker2D,
	enemy: CharacterBody2D
) -> void:

	# Solo eliminar la referencia si corresponde al enemigo registrado.
	if enemigos_por_spawn.get(spawn_point) == enemy:
		enemigos_por_spawn.erase(spawn_point)

	enemigos_actuales = max(enemigos_actuales - 1, 0)

	if enemy is Danable:
		enemy_removed.emit(enemy as Danable)

# =========================================================
# REINICIAR ESTADO DEL SPAWN
# =========================================================
func reiniciar() -> void:

	# Guardar referencias antes de limpiar el diccionario.
	var enemigos: Array = enemigos_por_spawn.values()

	# Limpiar inmediatamente el estado interno del Spawner.
	enemigos_por_spawn.clear()
	enemigos_actuales = 0

	# Avisar al Hub que todos los enemigos actuales serán descartados.
	enemies_reset.emit()

	# Liberar los enemigos actuales.
	for enemy in enemigos:
		if is_instance_valid(enemy):
			enemy.queue_free()

	# Esperar a que Godot procese queue_free().
	await get_tree().process_frame

	# Crear nuevamente la cantidad inicial.
	crear_enemigos_iniciales()
