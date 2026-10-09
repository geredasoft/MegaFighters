extends CanvasLayer

const EnemyHealthBarScript = preload(
	"res://scripts/iu/enemy_health_bar.gd"
)


# =========================================================
# REFERENCIAS
# =========================================================

@export var jugador: Danable
@export var enemy_spawner: EnemySpawner


# =========================================================
# NODOS DE LA UI
# =========================================================

@onready var barra_player: ProgressBar = \
	$Control/MarginContainerPlayer/HBoxContainer/ProgressBarPlayer

@onready var contenedor_barras: VBoxContainer = \
	$Control/MarginContainerEnemigos/ContenedorBarrasEnemigos


# =========================================================
# ESTADO
# =========================================================

# Diccionario:
# enemigo -> fila HBoxContainer
#
# Ejemplo:
# {
#     Enemy1: HBoxContainer,
#     Enemy2: HBoxContainer
# }
var barras_enemigos: Dictionary = {}


# =========================================================
# READY
# =========================================================

func _ready() -> void:

	_configurar_jugador()
	_conectar_enemy_spawner()


# =========================================================
# CONFIGURAR JUGADOR
# =========================================================

func _configurar_jugador() -> void:

	if jugador == null:
		push_warning("Hub: jugador no está asignado.")
		return

	barra_player.max_value = jugador.vida_maxima
	barra_player.value = jugador.vida_actual

	if not jugador.vida_cambiada.is_connected(
		_on_jugador_vida_cambiada
	):
		jugador.vida_cambiada.connect(
			_on_jugador_vida_cambiada
		)


# =========================================================
# CONECTAR ENEMY SPAWNER
# =========================================================

func _conectar_enemy_spawner() -> void:

	if enemy_spawner == null:
		push_warning(
			"Hub: EnemySpawner no está asignado."
		)
		return

	if not enemy_spawner.enemy_spawned.is_connected(
		_on_enemy_spawned
	):
		enemy_spawner.enemy_spawned.connect(
			_on_enemy_spawned
		)

	if not enemy_spawner.enemy_removed.is_connected(
		_on_enemy_removed
	):
		enemy_spawner.enemy_removed.connect(
			_on_enemy_removed
		)

	if not enemy_spawner.enemies_reset.is_connected(
		_on_enemies_reset
	):
		enemy_spawner.enemies_reset.connect(
			_on_enemies_reset
	)


# =========================================================
# VIDA DEL PLAYER
# =========================================================

func _on_jugador_vida_cambiada(
	actual: int,
	maxima: int
) -> void:

	barra_player.max_value = maxima
	barra_player.value = actual


# =========================================================
# ENEMY SPAWNED
# =========================================================

func _on_enemy_spawned(enemy: Danable) -> void:

	if enemy == null:
		return

	if not is_instance_valid(enemy):
		return

	# Evitar registrar dos veces el mismo enemigo.
	if barras_enemigos.has(enemy):
		return

	_crear_barra_enemigo(enemy)

	_actualizar_nombres_enemigos()


# =========================================================
# CREAR BARRA DEL ENEMIGO
# =========================================================

func _crear_barra_enemigo(enemy: Danable) -> void:
	var fila: HBoxContainer = EnemyHealthBarScript.new()
	fila.call("configurar", enemy, "Enemy")
	contenedor_barras.add_child(fila)
	barras_enemigos[enemy] = fila


# =========================================================
# ENEMY REMOVED
# =========================================================

func _on_enemy_removed(enemy: Danable) -> void:

	if enemy == null:
		return

	if not barras_enemigos.has(enemy):
		return

	var fila: HBoxContainer = barras_enemigos[enemy]

	if not is_instance_valid(fila):
		return

	fila.call("marcar_derrotado")

# =========================================================
# RESET DE ENEMIGOS
# =========================================================

func _on_enemies_reset() -> void:

	# Eliminar todas las filas visuales.
	for fila in barras_enemigos.values():

		if is_instance_valid(fila):
			fila.queue_free()

	# Limpiar completamente el diccionario.
	barras_enemigos.clear()


# =========================================================
# ACTUALIZAR NOMBRES
# =========================================================

func _actualizar_nombres_enemigos() -> void:

	var numero: int = 1

	for enemigo in barras_enemigos.keys():

		if not is_instance_valid(enemigo):
			continue

		var fila: HBoxContainer = barras_enemigos[enemigo]

		if not is_instance_valid(fila):
			continue

		fila.call("asignar_nombre", "Enemy " + str(numero))

		numero += 1
