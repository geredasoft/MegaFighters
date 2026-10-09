extends RichTextLabel
class_name Juego

const GameFlowControllerScript = preload(
	"res://scripts/components/game_flow_controller.gd"
)
const LevelMessageViewScript = preload("res://scripts/iu/level_message_view.gd")

var _controlador_flujo
var _vista_mensaje

# =========================================================
# REFERENCIAS
# =========================================================

@export var jugador: Danable

@export var enemy_spawner: EnemySpawner


# =========================================================
# NIVELES
# =========================================================

@export_category("Niveles")

@export var escena_siguiente: PackedScene
@export_multiline var mensaje_victoria: String = (
	"¡NIVEL 1 COMPLETADO!\n\nPresiona ENTER para continuar al Nivel 2."
)
@export_range(0.0, 60.0, 0.5) var espera_transicion_victoria: float = 0.0


# =========================================================
# CONTROLADOR
# =========================================================

func _ready() -> void:
	_vista_mensaje = LevelMessageViewScript.new(self)
	_controlador_flujo = GameFlowControllerScript.new(
		_vista_mensaje,
		get_tree(),
		jugador,
		enemy_spawner,
		escena_siguiente,
		mensaje_victoria,
		espera_transicion_victoria
	)

	if enemy_spawner != null:
		if not enemy_spawner.todos_los_enemigos_derrotados.is_connected(
			_on_todos_los_enemigos_derrotados
		):
			enemy_spawner.todos_los_enemigos_derrotados.connect(
				_on_todos_los_enemigos_derrotados
			)

	MusicManager.reproducir_musica()
	_vista_mensaje.call("ocultar")


# =========================================================
# PLAYER - JUGADOR MURIÓ
# =========================================================

func _on_player_jugador_murio() -> void:
	_controlador_flujo.jugador_murio()


# =========================================================
# PLAYER - SOLICITÓ REINICIO
# =========================================================

func _on_player_solicitado_reiniciar() -> void:
	_controlador_flujo.jugador_solicito_reinicio()


# =========================================================
# NIVEL COMPLETADO
# =========================================================

func _on_todos_los_enemigos_derrotados() -> void:
	_controlador_flujo.enemigos_derrotados()


# =========================================================
# INPUT
# =========================================================

func _unhandled_input(event: InputEvent) -> void:
	_controlador_flujo.procesar_entrada(event)


# =========================================================
# PASAR A LA SIGUIENTE ESCENA
# =========================================================

func pasar_a_la_siguiente_escena() -> void:
	_controlador_flujo.pasar_a_la_siguiente_escena()


# =========================================================
# REINICIAR JUEGO
# =========================================================

func reiniciar() -> void:
	await _controlador_flujo.reiniciar()
