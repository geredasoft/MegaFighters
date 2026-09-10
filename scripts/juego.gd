extends RichTextLabel

@export var jugador: Danable
@export var spawn: Node2D

var jugador_ini_pos: Vector2

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	jugador_ini_pos = jugador.global_position
	hide()
	
func reiniciar() -> void:
	jugador.reiniciador.aplicar()
	spawn.reiniciador.aplicar()
	hide()


func _on_player_solicitado_reiniciar() -> void:
	reiniciar()


func _on_player_jugador_murio() -> void:
	show()
