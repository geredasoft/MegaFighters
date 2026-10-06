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


	# =====================================================
	# REGISTRAR SPAWN POINT COMO OCUPADO
	# =====================================================

	enemigos_por_spawn[spawn_point] = enemy


	# =====================================================
	# CONTADOR
	# =====================================================

	enemigos_actuales += 1


	# =====================================================
	# DETECTAR ELIMINACIÓN
	# =====================================================

	enemy.tree_exited.connect(
		_on_enemy_tree_exited.bind(spawn_point)
	)


# =========================================================
# ENEMIGO ELIMINADO
# =========================================================

func _on_enemy_tree_exited(spawn_point: Marker2D) -> void:

	# Liberar el SpawnPoint

	if enemigos_por_spawn.has(spawn_point):

		enemigos_por_spawn.erase(spawn_point)


	# Actualizar contador

	enemigos_actuales = maxi(
		enemigos_actuales - 1,
		0
	)

# =========================================================
# REINICIAR ESTADO DEL SPAWN
# =========================================================
func reiniciar():
	var enemies = enemigos_por_spawn.values()
	
	for en in enemies:
		en.queue_free()
		
	await get_tree().process_frame
	
	crear_enemigos_iniciales()
