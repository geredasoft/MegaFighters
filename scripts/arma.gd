extends Area2D

var _personajes_cercanos: Array[Node2D] = []
var _recogida_en_proceso := false
var _en_caida := false


func _ready() -> void:
	# Player está en la capa 2 y enemy en la capa 3.
	collision_mask = 2 | 4
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _process(_delta: float) -> void:
	if _recogida_en_proceso or _en_caida:
		return

	for personaje in _personajes_cercanos:
		if not is_instance_valid(personaje):
			continue

		if personaje.is_in_group("enemy"):
			_recoger(personaje)
			return

		if personaje.is_in_group("Player"):
			var agachado := Input.is_key_pressed(KEY_DOWN) or Input.is_action_pressed("ui_down")
			var presiona_x := Input.is_key_pressed(KEY_X) or Input.is_action_pressed("attack")
			if agachado and presiona_x:
				_recoger(personaje)
				return
func _on_body_entered(body: Node2D) -> void:
	if _en_caida:
		return
	if body.is_in_group("Player") or body.is_in_group("enemy"):
		if not _personajes_cercanos.has(body):
			_personajes_cercanos.append(body)


func _on_body_exited(body: Node2D) -> void:
	_personajes_cercanos.erase(body)


func iniciar_caida(_personaje_que_suelta: Node2D, direccion: float) -> void:
	_en_caida = true
	_personajes_cercanos.clear()
	monitoring = false
	var inicio := global_position
	var salida := signf(direccion)
	if is_zero_approx(salida):
		salida = 1.0
	var punto_alto := inicio + Vector2(salida * 28.0, -42.0)
	var punto_caida := inicio + Vector2(salida * 52.0, 8.0)
	var tween := create_tween()
	tween.tween_property(self, "global_position", punto_alto, 0.18)
	tween.parallel().tween_property(self, "rotation", rotation + TAU, 0.46)
	tween.tween_property(self, "global_position", punto_caida, 0.28)
	tween.parallel().tween_property(self, "rotation", 0.0, 0.28)
	tween.tween_callback(_finalizar_caida)


func _finalizar_caida() -> void:
	var sprite := get_node_or_null("Sprite2D") as Sprite2D
	if sprite == null:
		queue_free()
		return
	var tween := create_tween()
	tween.tween_interval(0.25)
	tween.tween_property(sprite, "modulate:a", 0.0, 0.25)
	tween.tween_callback(queue_free)
func _recoger(personaje: Node2D) -> void:
	if _recogida_en_proceso:
		return
	_recogida_en_proceso = true
	var nombre_personaje := "Player" if personaje.is_in_group("Player") else "enemy"
	var sprite := get_node_or_null("Sprite2D") as Sprite2D
	var nombre_arma := _obtener_nombre_arma(sprite)
	print("%s recogió el arma: %s" % [nombre_personaje, nombre_arma])
	if sprite != null and personaje.has_method("recoger_arma"):
		personaje.call("recoger_arma", sprite.texture, nombre_arma)
	queue_free()


func _obtener_nombre_arma(sprite: Sprite2D) -> String:
	# El nombre de instancia puede ser @Area2D@123 y el Texture2D puede
	# conservar un UID en vez de una ruta res://; la escena es la fuente
	# estable para identificar el arma y elegir sus balas.
	var ruta := scene_file_path
	if not ruta.is_empty():
		var nombre_escena := ruta.get_file().get_basename()
		if not nombre_escena.is_empty():
			return nombre_escena.to_lower()
	if sprite != null and sprite.texture != null:
		var nombre_recurso := sprite.texture.resource_path.get_file().get_basename()
		if not nombre_recurso.is_empty():
			return nombre_recurso.to_lower()
	if not name.begins_with("@"):
		return name.to_lower()
	return "Arma"
