extends RichTextLabel
class_name Juego


# =========================================================
# REFERENCIAS
# =========================================================

@export var jugador: Danable
@export var enemy_spawner: EnemySpawner


# =========================================================
# ESTADO
# =========================================================

var jugador_ini_pos: Vector2
var reiniciando: bool = false


# =========================================================
# READY
# =========================================================

func _ready() -> void:

	if jugador != null:
		jugador_ini_pos = jugador.global_position

	hide()


# =========================================================
# PLAYER - JUGADOR MURIÓ
# =========================================================

func _on_player_jugador_murio() -> void:

	if reiniciando:
		return

	print("💀 Jugador murió.")

	show()


# =========================================================
# PLAYER - SOLICITÓ REINICIO
# =========================================================

func _on_player_solicitado_reiniciar() -> void:

	if reiniciando:
		return

	print("🔄 Jugador solicitó reiniciar.")

	reiniciar()


# =========================================================
# INPUT MANUAL
# =========================================================

func _unhandled_input(event: InputEvent) -> void:

	if not visible:
		return

	if reiniciando:
		return

	if event is InputEventKey:

		if event.pressed and not event.echo:

			if event.keycode == KEY_R:
				reiniciar()


# =========================================================
# REINICIAR JUEGO
# =========================================================

func reiniciar() -> void:

	if reiniciando:
		return

	reiniciando = true

	# Ocultar inmediatamente el mensaje.
	hide()

	print("========================================")
	print("🔄 REINICIANDO JUEGO")
	print("========================================")


	# =====================================================
	# REINICIAR PLAYER
	# =====================================================

	if jugador != null:

		if jugador.has_method("reiniciar"):
			jugador.reiniciar()

		else:
			jugador.global_position = jugador_ini_pos


	# =====================================================
	# REINICIAR ENEMIGOS
	# =====================================================

	if enemy_spawner != null:

		await enemy_spawner.reiniciar()

	else:

		push_error(
			"Juego: EnemySpawner no está asignado."
		)

		reiniciando = false
		return


	# =====================================================
	# FINALIZAR
	# =====================================================

	reiniciando = false

	print("========================================")
	print("✅ JUEGO REINICIADO")
	print("========================================")
