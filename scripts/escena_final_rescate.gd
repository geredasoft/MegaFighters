extends Node2D

@onready var video_player: VideoStreamPlayer = $VideoStreamPlayer

func _ready() -> void:
	video_player.connect("finished", mostrar_menu_final)

func mostrar_menu_final() -> void:
	get_tree().change_scene_to_file("res://scenes/menu_final.tscn")
