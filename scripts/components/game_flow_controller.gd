extends RefCounted

var _vista_mensaje
var _scene_tree: SceneTree
var _jugador: Danable
var _enemy_spawner: EnemySpawner
var _escena_siguiente: PackedScene
var _mensaje_victoria: String
var _espera_transicion_victoria: float

var _reiniciando: bool = false
var _nivel_completado: bool = false
var _transicion_automatica_pendiente: bool = false


func _init(
	vista_mensaje,
	scene_tree: SceneTree,
	jugador: Danable,
	enemy_spawner: EnemySpawner,
	escena_siguiente: PackedScene,
	mensaje_victoria: String,
	espera_transicion_victoria: float
) -> void:
	_vista_mensaje = vista_mensaje
	_scene_tree = scene_tree
	_jugador = jugador
	_enemy_spawner = enemy_spawner
	_escena_siguiente = escena_siguiente
	_mensaje_victoria = mensaje_victoria
	_espera_transicion_victoria = maxf(espera_transicion_victoria, 0.0)

	if _enemy_spawner == null:
		push_error("Juego: EnemySpawner no está asignado.")


func jugador_murio() -> void:
	if _reiniciando:
		return

	_nivel_completado = false
	_transicion_automatica_pendiente = false
	print("💀 Jugador murió.")
	_vista_mensaje.call("mostrar_derrota")


func jugador_solicito_reinicio() -> void:
	if _reiniciando or _nivel_completado:
		return

	print("🔄 Jugador solicitó reiniciar.")
	reiniciar()


func enemigos_derrotados() -> void:
	if _reiniciando or _nivel_completado:
		return
	if not _jugador_sigue_vivo():
		return

	_nivel_completado = true
	_vista_mensaje.call("mostrar_victoria", _mensaje_victoria)
	print("🏆 NIVEL COMPLETADO")
	if _espera_transicion_victoria > 0.0:
		_transicion_automatica_pendiente = true
		_esperar_y_pasar_a_la_siguiente_escena()


func _jugador_sigue_vivo() -> bool:
	return (
		_jugador != null
		and is_instance_valid(_jugador)
		and not _jugador.esta_muerto()
	)


func _esperar_y_pasar_a_la_siguiente_escena() -> void:
	await _scene_tree.create_timer(_espera_transicion_victoria).timeout
	if not _transicion_automatica_pendiente or not _nivel_completado:
		return
	if not _jugador_sigue_vivo():
		return
	_transicion_automatica_pendiente = false
	pasar_a_la_siguiente_escena()


func procesar_entrada(event: InputEvent) -> void:
	if _reiniciando:
		return
	if _transicion_automatica_pendiente:
		return
	if not event is InputEventKey:
		return
	if not event.pressed or event.echo:
		return
	var entrada_teclado := event as InputEventKey

	if _nivel_completado:
		if entrada_teclado.keycode == KEY_ENTER or entrada_teclado.keycode == KEY_KP_ENTER:
			pasar_a_la_siguiente_escena()
		return

	if _vista_mensaje.call("esta_visible") and entrada_teclado.keycode == KEY_R:
		reiniciar()


func pasar_a_la_siguiente_escena() -> void:
	if not _nivel_completado or not _jugador_sigue_vivo():
		return
	if _escena_siguiente == null:
		push_error("Juego: No se ha asignado la siguiente escena.")
		return

	print("➡️ Cargando la siguiente escena...")
	_scene_tree.change_scene_to_packed(_escena_siguiente)


func reiniciar() -> void:
	if _reiniciando:
		return

	_reiniciando = true
	_nivel_completado = false
	_transicion_automatica_pendiente = false
	_vista_mensaje.call("ocultar")

	print("========================================")
	print("🔄 REINICIANDO JUEGO")
	print("========================================")

	if _jugador != null:
		_jugador.reiniciar()

	if _enemy_spawner == null:
		push_error("Juego: EnemySpawner no está asignado.")
		_reiniciando = false
		return

	await _enemy_spawner.reiniciar()
	_reiniciando = false

	print("========================================")
	print("✅ JUEGO REINICIADO")
	print("========================================")
