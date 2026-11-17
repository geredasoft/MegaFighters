extends HBoxContainer

const COLOR_RELLENO_VIDA := Color("#0e6900")
const COLOR_SIN_VIDA := Color("#2a2a2a")

var _etiqueta_nombre: Label
var _barra: ProgressBar
var _marco_arma: PanelContainer
var _icono_arma: TextureRect
var _enemigo: Danable


func configurar(enemigo: Danable, nombre: String) -> void:
	if enemigo == null or not is_instance_valid(enemigo):
		push_warning("EnemyHealthBar: el enemigo no es válido.")
		return

	_enemigo = enemigo
	_construir_vista()
	asignar_nombre(nombre)
	_actualizar_vida(enemigo.vida_actual, enemigo.vida_maxima)

	if not enemigo.vida_cambiada.is_connected(_actualizar_vida):
		enemigo.vida_cambiada.connect(_actualizar_vida)


func asignar_nombre(nombre: String) -> void:
	if is_instance_valid(_etiqueta_nombre):
		_etiqueta_nombre.text = nombre


func asignar_arma(textura: Texture2D) -> void:
	if not is_instance_valid(_marco_arma):
		return
	_icono_arma.texture = textura
	_marco_arma.visible = textura != null


func marcar_derrotado() -> void:
	if not is_instance_valid(_barra):
		return

	_barra.value = 0
	_obtener_relleno().bg_color = COLOR_SIN_VIDA


func _construir_vista() -> void:
	add_theme_constant_override("separation", 10)

	_etiqueta_nombre = Label.new()
	_etiqueta_nombre.name = "NombreEnemy"
	_etiqueta_nombre.text = "Enemy"
	_etiqueta_nombre.add_theme_font_size_override("font_size", 12)
	add_child(_etiqueta_nombre)

	_barra = ProgressBar.new()
	_barra.name = "BarraVida"
	_barra.custom_minimum_size = Vector2(110, 14)
	_barra.show_percentage = true
	_barra.add_theme_font_size_override("font_size", 10)

	var estilo_fondo := StyleBoxFlat.new()
	estilo_fondo.bg_color = COLOR_SIN_VIDA
	_barra.add_theme_stylebox_override("background", estilo_fondo)

	var estilo_relleno := StyleBoxFlat.new()
	estilo_relleno.bg_color = COLOR_RELLENO_VIDA
	_barra.add_theme_stylebox_override("fill", estilo_relleno)
	add_child(_barra)

	_marco_arma = PanelContainer.new()
	_marco_arma.name = "MarcoArma"
	_marco_arma.custom_minimum_size = Vector2(14, 14)
	var estilo_marco := StyleBoxFlat.new()
	estilo_marco.bg_color = Color.WHITE
	estilo_marco.border_color = Color.BLACK
	estilo_marco.set_border_width_all(1)
	estilo_marco.set_content_margin_all(2)
	_marco_arma.add_theme_stylebox_override("panel", estilo_marco)
	add_child(_marco_arma)

	_icono_arma = TextureRect.new()
	_icono_arma.name = "IconoArma"
	_icono_arma.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_icono_arma.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icono_arma.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_marco_arma.add_child(_icono_arma)


func _actualizar_vida(actual: int, maxima: int) -> void:
	if not is_instance_valid(_barra):
		return

	_barra.max_value = maxima
	_barra.value = actual
	_obtener_relleno().bg_color = (
		COLOR_SIN_VIDA if actual <= 0 else COLOR_RELLENO_VIDA
	)


func _obtener_relleno() -> StyleBoxFlat:
	return _barra.get_theme_stylebox("fill") as StyleBoxFlat
