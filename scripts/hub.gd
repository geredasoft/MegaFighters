extends CanvasLayer


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

	# -----------------------------------------------------
	# FILA
	# -----------------------------------------------------

	var fila_contenedor := HBoxContainer.new()

	fila_contenedor.add_theme_constant_override(
		"separation",
		10
	)


	# -----------------------------------------------------
	# ETIQUETA
	# -----------------------------------------------------

	var etiqueta := Label.new()

	etiqueta.name = "NombreEnemy"
	etiqueta.text = "Enemy"

	etiqueta.add_theme_font_size_override(
		"font_size",
		12
	)


	# -----------------------------------------------------
	# BARRA DE VIDA
	# -----------------------------------------------------

	var nueva_barra := ProgressBar.new()

	nueva_barra.name = "BarraVida"

	nueva_barra.custom_minimum_size = Vector2(
		110,
		14
	)

	nueva_barra.max_value = enemy.vida_maxima
	nueva_barra.value = enemy.vida_actual

	nueva_barra.show_percentage = true

	nueva_barra.add_theme_font_size_override(
		"font_size",
		10
	)


	# -----------------------------------------------------
	# ESTILO DE FONDO
	# -----------------------------------------------------

	var estilo_fondo := StyleBoxFlat.new()

	estilo_fondo.bg_color = Color("#2a2a2a")

	nueva_barra.add_theme_stylebox_override(
		"background",
		estilo_fondo
	)


	# -----------------------------------------------------
	# ESTILO DE RELLENO
	# -----------------------------------------------------

	var estilo_relleno := StyleBoxFlat.new()

	estilo_relleno.bg_color = Color("#0e6900")

	nueva_barra.add_theme_stylebox_override(
		"fill",
		estilo_relleno
	)


	# -----------------------------------------------------
	# CONSTRUIR FILA
	# -----------------------------------------------------

	fila_contenedor.add_child(etiqueta)
	fila_contenedor.add_child(nueva_barra)

	contenedor_barras.add_child(
		fila_contenedor
	)


	# -----------------------------------------------------
	# REGISTRAR
	# -----------------------------------------------------

	barras_enemigos[enemy] = fila_contenedor


	# -----------------------------------------------------
	# CONECTAR VIDA
	# -----------------------------------------------------

	if not enemy.vida_cambiada.is_connected(
		_on_enemigo_vida_cambiada.bind(enemy)
	):
		enemy.vida_cambiada.connect(
			_on_enemigo_vida_cambiada.bind(enemy)
		)


# =========================================================
# VIDA DEL ENEMIGO
# =========================================================

func _on_enemigo_vida_cambiada(
	actual: int,
	maxima: int,
	enemigo: Danable
) -> void:

	if enemigo == null:
		return

	if not barras_enemigos.has(enemigo):
		return

	var fila: HBoxContainer = barras_enemigos[enemigo]

	if not is_instance_valid(fila):
		return

	var barra := fila.get_node_or_null(
		"BarraVida"
	) as ProgressBar

	if barra == null:
		return

	barra.max_value = maxima
	barra.value = actual


	# -----------------------------------------------------
	# CAMBIO DE COLOR SEGÚN VIDA
	# -----------------------------------------------------

	var relleno := barra.get_theme_stylebox(
		"fill"
	) as StyleBoxFlat

	if relleno == null:
		return

	if actual <= 0:
		relleno.bg_color = Color("#2a2a2a")
	else:
		relleno.bg_color = Color("#0e6900")


# =========================================================
# ENEMY REMOVED
# =========================================================

func _on_enemy_removed(enemy: Danable) -> void:

	if enemy == null:
		return

	if not barras_enemigos.has(enemy):
		return

	var fila: HBoxContainer = barras_enemigos[enemy]

	if is_instance_valid(fila):
		fila.queue_free()

	barras_enemigos.erase(enemy)

	_actualizar_nombres_enemigos()


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

		var etiqueta := fila.get_node_or_null(
			"NombreEnemy"
		) as Label

		if etiqueta == null:
			continue

		etiqueta.text = "Enemy " + str(numero)

		numero += 1
