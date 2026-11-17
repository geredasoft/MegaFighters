extends RefCounted


static func soltar(dueno: Danable, nombre_arma: String, direccion: float) -> void:
	if dueno == null or not is_instance_valid(dueno):
		return
	var clave := nombre_arma.to_lower()
	var ruta := "res://scenes/armas/%s.tscn" % clave
	var escena_arma := load(ruta) as PackedScene
	if escena_arma == null:
		push_warning("No se encontró la escena del arma para soltar: " + ruta)
		return
	var escena_actual := dueno.get_tree().current_scene
	if escena_actual == null:
		return
	var arma := escena_arma.instantiate() as Area2D
	if arma == null:
		return
	var salida := signf(direccion)
	if is_zero_approx(salida):
		salida = 1.0
	arma.global_position = dueno.global_position + Vector2(salida * 18.0, -10.0)
	escena_actual.add_child.call_deferred(arma)
	arma.call_deferred("iniciar_caida", dueno, salida)
