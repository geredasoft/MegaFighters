@abstract
class_name Danable
extends CharacterBody2D


# =========================================================
# VIDA
# =========================================================

@export var vida_maxima: int = 100

@onready var vida_actual: int = vida_maxima


# =========================================================
# SEÑALES
# =========================================================

signal vida_cambiada(actual: int, maxima: int)
signal murio()


# =========================================================
# MÉTODOS ABSTRACTOS
# =========================================================

@abstract
func morir() -> void


@abstract
func esta_muerto() -> bool


@abstract
func reiniciar() -> void


@abstract
func recibir_empuje(
	direccion: float,
	fuerza_vertical: float = -180.0
) -> void


@abstract
func aplicar_efecto_portal(
	nueva_posicion: Vector2,
	nueva_velocidad: Vector2
) -> void


@abstract
func cambiar_gravedad(invertir: bool = true) -> void


@abstract
func aplicar_damping(x: float = 0.0) -> void


# =========================================================
# RECIBIR DAÑO
# =========================================================

func recibir_dano(
	cantidad: int,
	atacante: Node2D = null
) -> void:

	# No recibir daño si ya está muerto.
	if esta_muerto():
		return

	# Ignorar daño inválido.
	if cantidad <= 0:
		return

	# Evitar daño entre entidades de la misma facción.
	if atacante and _es_misma_faccion(atacante):
		return


	# =====================================================
	# APLICAR DAÑO
	# =====================================================

	vida_actual = maxi(
		vida_actual - cantidad,
		0
	)


	# =====================================================
	# NOTIFICAR CAMBIO DE VIDA
	# =====================================================

	vida_cambiada.emit(
		vida_actual,
		vida_maxima
	)


	# =====================================================
	# COMPROBAR MUERTE
	# =====================================================

	if vida_actual <= 0:

		# Avisar a los sistemas interesados.
		murio.emit()

		# Ejecutar comportamiento específico de muerte.
		morir()


# =========================================================
# COMPROBAR MISMA FACCION
# =========================================================

func _es_misma_faccion(otro: Node2D) -> bool:

	var soy_player: bool = is_in_group("Player")
	var otro_es_player: bool = otro.is_in_group("Player")

	var soy_enemigo: bool = is_in_group("enemy")
	var otro_es_enemigo: bool = otro.is_in_group("enemy")

	return (
		(soy_player and otro_es_player)
		or
		(soy_enemigo and otro_es_enemigo)
	)


# =========================================================
# REINICIAR VIDA
# =========================================================

func reiniciar_vida() -> void:

	vida_actual = vida_maxima

	vida_cambiada.emit(
		vida_actual,
		vida_maxima
	)
