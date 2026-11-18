extends AnimatableBody2D

enum Direccion {
	HORIZONTAL,
	VERTICAL
}

@export_category("Movimiento")
@export var direccion: Direccion = Direccion.HORIZONTAL
@export var distancia: float = 200.0
@export var velocidad: float = 100.0

var posicion_inicial: Vector2
var posicion_objetivo: Vector2
var moviendo_hacia_objetivo := true
var velocidad_lineal_calculada: Vector2 = Vector2.ZERO


func _ready() -> void:
	add_to_group("plataforma_movil")
	sync_to_physics = true
	_configurar_apariencia()

	posicion_inicial = global_position

	if direccion == Direccion.HORIZONTAL:
		posicion_objetivo = posicion_inicial + Vector2(distancia, 0.0)
	else:
		posicion_objetivo = posicion_inicial + Vector2(0.0, distancia)


func _configurar_apariencia() -> void:
	# Textura pequeña en pixel art: franjas de advertencia y borde oscuro.
	var imagen := Image.create(128, 12, false, Image.FORMAT_RGBA8)
	var amarillo := Color("ffd21a")
	var negro := Color("171717")
	for y in range(12):
		for x in range(128):
			var es_borde := x < 2 or x >= 126 or y < 2 or y >= 10
			var color := negro if es_borde or floori(float(x + y * 2) / 12.0) % 2 == 0 else amarillo
			imagen.set_pixel(x, y, color)

	var sprite := get_node_or_null("Sprite2D") as Sprite2D
	if sprite != null:
		sprite.texture = ImageTexture.create_from_image(imagen)
		sprite.scale = Vector2(0.5, 0.5)
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func _physics_process(delta: float) -> void:
	var objetivo := posicion_objetivo if moviendo_hacia_objetivo else posicion_inicial
	var anterior_pos := global_position

	global_position = global_position.move_toward(objetivo, velocidad * delta)

	if delta > 0.0:
		velocidad_lineal_calculada = (global_position - anterior_pos) / delta

	if global_position.distance_to(objetivo) < 0.5:
		global_position = objetivo
		moviendo_hacia_objetivo = not moviendo_hacia_objetivo
