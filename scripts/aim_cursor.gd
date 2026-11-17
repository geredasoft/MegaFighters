extends Node2D

const COLOR_SOMBRA := Color(0.02, 0.025, 0.04, 0.95)
const COLOR_MIRA := Color(1.0, 0.88, 0.2, 1.0)


func _ready() -> void:
	z_index = 100
	queue_redraw()


func _draw() -> void:
	var brazo := 9.0
	draw_line(Vector2(-brazo, 0), Vector2(brazo, 0), COLOR_SOMBRA, 5.0, true)
	draw_line(Vector2(0, -brazo), Vector2(0, brazo), COLOR_SOMBRA, 5.0, true)
	draw_circle(Vector2.ZERO, 4.0, COLOR_SOMBRA)
	draw_line(Vector2(-brazo, 0), Vector2(brazo, 0), COLOR_MIRA, 2.0, true)
	draw_line(Vector2(0, -brazo), Vector2(0, brazo), COLOR_MIRA, 2.0, true)
	draw_circle(Vector2.ZERO, 2.0, COLOR_MIRA)
