extends CanvasLayer

const CANTIDAD_ENEMIGOS_UI := 5
const ALTO_BARRA := 9.0
const ALTO_FRANJA_HUD := 112.0
const TAMANO_RETRATO := Vector2(34, 34)
const TAMANO_ARMA := Vector2(22, 22)
const COLOR_VERDE := Color("#54e878")
const COLOR_NEGRO_TRANSPARENTE := Color(0.0, 0.0, 0.0, 1.0)
const COLOR_FONDO_ICONO_HUD := Color("#713b3e")
const COLOR_BORDE_ICONO_HUD := Color("#a35458")
const COLOR_TEXTO_ICONO_HUD := Color("#fff0ed")

@export var jugador: Danable
@export var enemy_spawner: EnemySpawner

var _control: Control
var _panel_principal: PanelContainer
var _rejilla: GridContainer
var _barra_player: ProgressBar
var _retrato_player: TextureRect
var _estado_player: Label
var _marco_arma_player: PanelContainer
var _icono_arma_player: TextureRect
var _tarjetas_enemigos: Array[Dictionary] = []
var _enemigos: Array[Danable] = []
var _vistas_actor: Dictionary = {}


func _ready() -> void:
	_control = $Control
	$Control/MarginContainerPlayer.hide()
	$Control/MarginContainerEnemigos.hide()
	_construir_hud()
	_configurar_jugador()
	_conectar_enemy_spawner()


func _process(_delta: float) -> void:
	_actualizar_retratos()


func _construir_hud() -> void:
	var fondo_superior := ColorRect.new()
	fondo_superior.name = "FondoNegroHUD"
	fondo_superior.anchor_right = 1.0
	fondo_superior.offset_bottom = ALTO_FRANJA_HUD
	fondo_superior.color = Color(0.0, 0.0, 0.0, 0.58)
	fondo_superior.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_control.add_child(fondo_superior)
	_control.move_child(fondo_superior, 0)

	_panel_principal = PanelContainer.new()
	_panel_principal.name = "PanelHUDSuperior"
	_panel_principal.anchor_right = 1.0
	_panel_principal.offset_left = 24.0
	_panel_principal.offset_right = -24.0
	_panel_principal.offset_top = 8.0
	_panel_principal.offset_bottom = ALTO_FRANJA_HUD - 8.0
	_panel_principal.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel_principal.add_theme_stylebox_override("panel", _estilo_panel(
		COLOR_NEGRO_TRANSPARENTE, Color(0.32, 0.67, 1.0, 0.9), 1, 6
	))
	_control.add_child(_panel_principal)

	var margen := MarginContainer.new()
	margen.add_theme_constant_override("margin_left", 5)
	margen.add_theme_constant_override("margin_right", 5)
	margen.add_theme_constant_override("margin_top", 3)
	margen.add_theme_constant_override("margin_bottom", 3)
	_panel_principal.add_child(margen)

	_rejilla = GridContainer.new()
	_rejilla.columns = 6
	_rejilla.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rejilla.add_theme_constant_override("h_separation", 4)
	margen.add_child(_rejilla)

	_construir_tarjeta_player()
	for indice in range(CANTIDAD_ENEMIGOS_UI):
		_tarjetas_enemigos.append(_construir_tarjeta_enemigo(indice + 1))
	_enemigos.resize(CANTIDAD_ENEMIGOS_UI)
	_enemigos.fill(null)


func _construir_tarjeta_base(titulo: String, acento: Color) -> Dictionary:
	var tarjeta := PanelContainer.new()
	tarjeta.custom_minimum_size = Vector2(165, 88)
	tarjeta.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tarjeta.add_theme_stylebox_override("panel", _estilo_panel(
		Color.BLACK, acento, 1, 6
	))
	_rejilla.add_child(tarjeta)

	var margen := MarginContainer.new()
	for lado in ["left", "right", "top", "bottom"]:
		margen.add_theme_constant_override("margin_" + lado, 4)
	tarjeta.add_child(margen)

	var columna := VBoxContainer.new()
	columna.add_theme_constant_override("separation", 2)
	margen.add_child(columna)

	var encabezado := HBoxContainer.new()
	encabezado.add_theme_constant_override("separation", 4)
	columna.add_child(encabezado)

	var etiqueta_titulo := Label.new()
	etiqueta_titulo.text = titulo
	etiqueta_titulo.add_theme_color_override("font_color", acento)
	etiqueta_titulo.add_theme_font_size_override("font_size", 11)
	etiqueta_titulo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	encabezado.add_child(etiqueta_titulo)

	var estado := Label.new()
	estado.text = "EN ESPERA"
	estado.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	estado.add_theme_color_override("font_color", Color("#b4c2d4"))
	estado.add_theme_font_size_override("font_size", 8)
	encabezado.add_child(estado)

	var cuerpo := HBoxContainer.new()
	cuerpo.add_theme_constant_override("separation", 5)
	cuerpo.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columna.add_child(cuerpo)

	var marco_retrato := PanelContainer.new()
	marco_retrato.custom_minimum_size = TAMANO_RETRATO
	marco_retrato.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	marco_retrato.add_theme_stylebox_override("panel", _estilo_panel(
		COLOR_FONDO_ICONO_HUD, COLOR_BORDE_ICONO_HUD, 1, 0
	))
	cuerpo.add_child(marco_retrato)

	var retrato := TextureRect.new()
	retrato.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	retrato.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	marco_retrato.add_child(retrato)

	var datos := VBoxContainer.new()
	datos.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	datos.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cuerpo.add_child(datos)

	var barra := ProgressBar.new()
	barra.custom_minimum_size = Vector2(0, ALTO_BARRA)
	barra.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	barra.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	barra.show_percentage = false
	barra.add_theme_stylebox_override("background", _estilo_panel(
		Color(0.12, 0.14, 0.18, 1), Color(0.25, 0.29, 0.35, 1), 1, 3
	))
	barra.add_theme_stylebox_override("fill", _estilo_panel(
		COLOR_VERDE, COLOR_VERDE, 0, 3
	))
	datos.add_child(barra)

	var fila_arma := HBoxContainer.new()
	fila_arma.add_theme_constant_override("separation", 6)
	fila_arma.size_flags_vertical = Control.SIZE_EXPAND_FILL
	datos.add_child(fila_arma)

	var marco_arma := PanelContainer.new()
	marco_arma.custom_minimum_size = TAMANO_ARMA
	marco_arma.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	marco_arma.add_theme_stylebox_override("panel", _estilo_panel(
		COLOR_FONDO_ICONO_HUD, COLOR_BORDE_ICONO_HUD, 1, 0
	))
	marco_arma.visible = false
	fila_arma.add_child(marco_arma)

	var icono_arma := TextureRect.new()
	icono_arma.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icono_arma.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	marco_arma.add_child(icono_arma)

	var marco_municion := PanelContainer.new()
	marco_municion.custom_minimum_size = TAMANO_ARMA
	marco_municion.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	marco_municion.add_theme_stylebox_override("panel", _estilo_panel(
		COLOR_FONDO_ICONO_HUD, COLOR_BORDE_ICONO_HUD, 1, 0
	))
	marco_municion.visible = false
	fila_arma.add_child(marco_municion)

	var contador_municion := Label.new()
	contador_municion.text = "0"
	contador_municion.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	contador_municion.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	contador_municion.add_theme_color_override("font_color", COLOR_TEXTO_ICONO_HUD)
	contador_municion.add_theme_font_size_override("font_size", 13)
	marco_municion.add_child(contador_municion)

	var texto_arma := Label.new()
	texto_arma.text = "SIN ARMA"
	texto_arma.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	texto_arma.add_theme_color_override("font_color", Color("#c7d0dc"))
	texto_arma.add_theme_font_size_override("font_size", 8)
	fila_arma.add_child(texto_arma)

	var fila_melee := HBoxContainer.new()
	fila_melee.add_theme_constant_override("separation", 6)
	fila_melee.visible = false
	datos.add_child(fila_melee)

	var marco_melee := PanelContainer.new()
	marco_melee.custom_minimum_size = TAMANO_ARMA
	marco_melee.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	marco_melee.add_theme_stylebox_override("panel", _estilo_panel(
		COLOR_FONDO_ICONO_HUD, COLOR_BORDE_ICONO_HUD, 1, 0
	))
	marco_melee.visible = false
	fila_melee.add_child(marco_melee)

	var icono_melee := TextureRect.new()
	icono_melee.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icono_melee.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	marco_melee.add_child(icono_melee)

	return {
		"tarjeta": tarjeta,
		"estado": estado,
		"retrato": retrato,
		"barra": barra,
		"marco_arma": marco_arma,
		"icono_arma": icono_arma,
		"texto_arma": texto_arma,
		"marco_municion": marco_municion,
		"contador_municion": contador_municion,
		"fila_melee": fila_melee,
		"marco_melee": marco_melee,
		"icono_melee": icono_melee
	}


func _construir_tarjeta_player() -> void:
	var vista := _construir_tarjeta_base("PLAYER", Color("#ff645c"))
	_estado_player = vista["estado"]
	_retrato_player = vista["retrato"]
	_barra_player = vista["barra"]
	_marco_arma_player = vista["marco_arma"]
	_icono_arma_player = vista["icono_arma"]
	_vistas_actor["player"] = vista


func _construir_tarjeta_enemigo(numero: int) -> Dictionary:
	var vista := _construir_tarjeta_base(
		"ENEMY %02d" % numero,
		Color("#6ab6ff") if numero % 2 == 1 else Color("#b68aff")
	)
	vista["estado"].text = "EN ESPERA"
	vista["barra"].max_value = 100
	vista["barra"].value = 0
	vista["texto_arma"].text = "SIN ARMA"
	return vista


func _estilo_panel(
	color_fondo: Color,
	color_borde: Color,
	ancho_borde: int,
	radio: int
) -> StyleBoxFlat:
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = color_fondo
	estilo.border_color = color_borde
	estilo.set_border_width_all(ancho_borde)
	estilo.set_corner_radius_all(radio)
	estilo.set_content_margin_all(3)
	return estilo


func _configurar_jugador() -> void:
	if jugador == null or not is_instance_valid(jugador):
		push_warning("Hub: jugador no está asignado.")
		return
	_conectar_actor(jugador, _vistas_actor["player"])
	if jugador.has_signal("arma_recogida"):
		var callback := Callable(self, "_on_arma_player_recogida")
		if not jugador.is_connected("arma_recogida", callback):
			jugador.connect("arma_recogida", callback)
	if jugador.has_signal("arma_cuerpo_a_cuerpo_recogida"):
		var callback_melee := Callable(self, "_on_arma_player_melee_recogida")
		if not jugador.is_connected("arma_cuerpo_a_cuerpo_recogida", callback_melee):
			jugador.connect("arma_cuerpo_a_cuerpo_recogida", callback_melee)
	if jugador.has_signal("municion_cambiada"):
		var callback_municion := Callable(self, "_on_municion_player_cambiada")
		if not jugador.is_connected("municion_cambiada", callback_municion):
			jugador.connect("municion_cambiada", callback_municion)
	if jugador.has_signal("arma_perdida"):
		var callback_perdida := Callable(self, "_on_arma_player_perdida")
		if not jugador.is_connected("arma_perdida", callback_perdida):
			jugador.connect("arma_perdida", callback_perdida)
	if jugador.get("textura_arma_recogida") is Texture2D:
		_on_arma_player_recogida(
			jugador.get("textura_arma_recogida"),
			jugador.get("nombre_arma_recogida"),
			jugador.get("municion_actual"),
			jugador.get("municion_maxima")
		)
	if jugador.get("textura_arma_cuerpo_a_cuerpo") is Texture2D:
		_on_arma_player_melee_recogida(
			jugador.get("textura_arma_cuerpo_a_cuerpo"),
			jugador.get("nombre_arma_cuerpo_a_cuerpo")
		)


func _conectar_actor(actor: Danable, vista: Dictionary) -> void:
	var barra: ProgressBar = vista["barra"]
	barra.max_value = actor.vida_maxima
	barra.value = actor.vida_actual
	if not actor.vida_cambiada.is_connected(_on_vida_cambiada.bind(actor)):
		actor.vida_cambiada.connect(_on_vida_cambiada.bind(actor))
	var sprite := actor.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	_vistas_actor[actor] = {
		"vista": vista,
		"sprite": sprite,
		"estado_base": "LISTO"
	}
	if sprite != null:
		_actualizar_vista_sprite(actor)


func _conectar_enemy_spawner() -> void:
	if enemy_spawner == null:
		push_warning("Hub: EnemySpawner no está asignado.")
		return
	if not enemy_spawner.enemy_spawned.is_connected(_on_enemy_spawned):
		enemy_spawner.enemy_spawned.connect(_on_enemy_spawned)
	if not enemy_spawner.enemy_removed.is_connected(_on_enemy_removed):
		enemy_spawner.enemy_removed.connect(_on_enemy_removed)
	if not enemy_spawner.enemies_reset.is_connected(_on_enemies_reset):
		enemy_spawner.enemies_reset.connect(_on_enemies_reset)


func _on_enemy_spawned(enemy: Danable) -> void:
	if enemy == null or not is_instance_valid(enemy) or _enemigos.has(enemy):
		return
	var indice := _buscar_slot_disponible()
	if indice < 0:
		return
	_enemigos[indice] = enemy
	var vista: Dictionary = _tarjetas_enemigos[indice]
	vista["estado"].text = "ACTIVO"
	vista["estado"].add_theme_color_override("font_color", COLOR_VERDE)
	_conectar_actor(enemy, vista)
	if enemy.has_signal("arma_recogida"):
		var callback := Callable(self, "_on_arma_enemy_recogida").bind(indice)
		if not enemy.is_connected("arma_recogida", callback):
			enemy.connect("arma_recogida", callback)
	if enemy.has_signal("arma_cuerpo_a_cuerpo_recogida"):
		var callback_melee := Callable(self, "_on_arma_enemy_melee_recogida").bind(indice)
		if not enemy.is_connected("arma_cuerpo_a_cuerpo_recogida", callback_melee):
			enemy.connect("arma_cuerpo_a_cuerpo_recogida", callback_melee)
	if enemy.has_signal("municion_cambiada"):
		var callback_municion := Callable(self, "_on_municion_enemy_cambiada").bind(indice)
		if not enemy.is_connected("municion_cambiada", callback_municion):
			enemy.connect("municion_cambiada", callback_municion)
	if enemy.has_signal("arma_perdida"):
		var callback_perdida := Callable(self, "_on_arma_enemy_perdida").bind(indice)
		if not enemy.is_connected("arma_perdida", callback_perdida):
			enemy.connect("arma_perdida", callback_perdida)
	if enemy.get("textura_arma_recogida") is Texture2D:
		_on_arma_enemy_recogida(
			enemy.get("textura_arma_recogida"),
			enemy.get("nombre_arma_recogida"),
			enemy.get("municion_actual"),
			enemy.get("municion_maxima"),
			indice
		)
	if enemy.get("textura_arma_cuerpo_a_cuerpo") is Texture2D:
		_on_arma_enemy_melee_recogida(
			enemy.get("textura_arma_cuerpo_a_cuerpo"),
			enemy.get("nombre_arma_cuerpo_a_cuerpo"),
			indice
		)


func _buscar_slot_disponible() -> int:
	for indice in range(_enemigos.size()):
		var enemigo: Danable = _enemigos[indice]
		if (
			enemigo == null
			or not is_instance_valid(enemigo)
			or (enemigo.has_method("esta_muerto") and enemigo.call("esta_muerto"))
		):
			return indice
	return -1


func _on_vida_cambiada(actual: int, maxima: int, actor: Danable) -> void:
	if not is_instance_valid(actor) or not _vistas_actor.has(actor):
		return
	var vista: Dictionary = _vistas_actor[actor]["vista"]
	var barra: ProgressBar = vista["barra"]
	barra.max_value = maxima
	barra.value = actual


func _on_arma_player_recogida(
	textura: Texture2D,
	nombre: String,
	municion: int,
	_capacidad: int
) -> void:
	_icono_arma_player.texture = textura
	_marco_arma_player.visible = textura != null
	var vista: Dictionary = _vistas_actor["player"]
	vista["texto_arma"].text = nombre.to_upper() if textura != null else "SIN ARMA"
	vista["marco_municion"].visible = textura != null
	vista["contador_municion"].text = str(municion)


func _on_arma_enemy_recogida(
	textura: Texture2D,
	nombre: String,
	municion: int,
	_capacidad: int,
	indice: int
) -> void:
	var vista: Dictionary = _tarjetas_enemigos[indice]
	vista["icono_arma"].texture = textura
	vista["marco_arma"].visible = textura != null
	vista["texto_arma"].text = nombre.to_upper() if textura != null else "SIN ARMA"
	vista["marco_municion"].visible = textura != null
	vista["contador_municion"].text = str(municion)


func _on_municion_player_cambiada(municion: int, _capacidad: int) -> void:
	_vistas_actor["player"]["contador_municion"].text = str(municion)


func _on_municion_enemy_cambiada(
	municion: int,
	_capacidad: int,
	indice: int
) -> void:
	_tarjetas_enemigos[indice]["contador_municion"].text = str(municion)


func _on_arma_player_perdida() -> void:
	_marco_arma_player.visible = false
	_vistas_actor["player"]["marco_municion"].visible = false
	_vistas_actor["player"]["texto_arma"].text = "SIN ARMA"


func _on_arma_enemy_perdida(indice: int) -> void:
	var vista: Dictionary = _tarjetas_enemigos[indice]
	vista["marco_arma"].visible = false
	vista["marco_municion"].visible = false
	vista["texto_arma"].text = "SIN ARMA"


func _on_arma_player_melee_recogida(textura: Texture2D, _nombre: String) -> void:
	var vista: Dictionary = _vistas_actor["player"]
	vista["icono_melee"].texture = textura
	vista["marco_melee"].visible = textura != null
	vista["fila_melee"].visible = textura != null


func _on_arma_enemy_melee_recogida(
	textura: Texture2D,
	_nombre: String,
	indice: int
) -> void:
	var vista: Dictionary = _tarjetas_enemigos[indice]
	vista["icono_melee"].texture = textura
	vista["marco_melee"].visible = textura != null
	vista["fila_melee"].visible = textura != null


func _on_enemy_removed(enemy: Danable) -> void:
	var indice := _enemigos.find(enemy)
	if indice < 0:
		return
	var vista: Dictionary = _tarjetas_enemigos[indice]
	vista["estado"].text = "DERROTADO"
	vista["estado"].add_theme_color_override("font_color", Color("#ff7777"))
	var barra: ProgressBar = vista["barra"]
	barra.value = 0
	_enemigos[indice] = null


func _on_enemies_reset() -> void:
	var vista_player: Dictionary = _vistas_actor.get("player", {})
	_enemigos.resize(CANTIDAD_ENEMIGOS_UI)
	_enemigos.fill(null)
	_vistas_actor.clear()
	_vistas_actor["player"] = vista_player
	if jugador != null and is_instance_valid(jugador):
		_conectar_actor(jugador, vista_player)
	for indice in range(CANTIDAD_ENEMIGOS_UI):
		var vista: Dictionary = _tarjetas_enemigos[indice]
		vista["estado"].text = "EN ESPERA"
		vista["estado"].add_theme_color_override("font_color", Color("#b4c2d4"))
		vista["barra"].value = 0
		vista["marco_arma"].visible = false
		vista["texto_arma"].text = "SIN ARMA"
		vista["marco_municion"].visible = false
		vista["contador_municion"].text = "0"
		vista["marco_melee"].visible = false
		vista["fila_melee"].visible = false
		vista["retrato"].texture = null


func _actualizar_retratos() -> void:
	for actor in _vistas_actor.keys():
		if actor is String and actor == "player":
			if jugador != null and is_instance_valid(jugador):
				_actualizar_vista_sprite(jugador)
			continue
		if actor is Danable and is_instance_valid(actor):
			_actualizar_vista_sprite(actor)


func _actualizar_vista_sprite(actor: Danable) -> void:
	if not _vistas_actor.has(actor):
		return
	var datos: Dictionary = _vistas_actor[actor]
	var vista: Dictionary = datos["vista"]
	var sprite: AnimatedSprite2D = datos["sprite"]
	if sprite == null or not is_instance_valid(sprite):
		return
	var textura := sprite.sprite_frames.get_frame_texture(
		sprite.animation, sprite.frame
	)
	vista["retrato"].texture = textura
	var estado_texto := String(sprite.animation).to_upper().replace("_", " ")
	if actor.has_method("esta_muerto") and actor.call("esta_muerto"):
		estado_texto = "DERROTADO"
	vista["estado"].text = estado_texto
