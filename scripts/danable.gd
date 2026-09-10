@abstract class_name Danable
extends CharacterBody2D

@export var vida_maxima: int = 100
@onready var vida_actual: int = vida_maxima

signal vida_cambiada(actual: int, maxima: int)

@abstract func morir() -> void
@abstract func esta_muerto() -> bool

func recibir_dano(cantidad: int, atacante: Node2D = null) -> void:
	if esta_muerto():
		return
		
	# Evitar daño entre entidades de la misma facción (ej. enemigo a enemigo)
	if atacante and _es_misma_faccion(atacante):
		return

	vida_actual = maxi(vida_actual - cantidad, 0)
	vida_cambiada.emit(vida_actual, vida_maxima)

	if vida_actual <= 0:
		morir()

func _es_misma_faccion(otro: Node2D) -> bool:
	var soy_player := self.is_in_group("player")
	var otro_es_player := otro.is_in_group("player")
	var soy_enemigo := self.is_in_group("enemy")
	var otro_es_enemigo := otro.is_in_group("enemy")
	
	return (soy_player and otro_es_player) or (soy_enemigo and otro_es_enemigo)

func reiniciar_vida() -> void:
	vida_actual = vida_maxima
	vida_cambiada.emit(vida_actual, vida_maxima)
