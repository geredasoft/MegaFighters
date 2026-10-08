extends Node

var musica_niveles = preload("res://assets/audio/musica_niveles.ogg")

var reproductor: AudioStreamPlayer


func _ready():
	reproductor = AudioStreamPlayer.new()
	reproductor.stream = musica_niveles
	reproductor.autoplay = false
	reproductor.volume_db = -10
	
	add_child(reproductor)


func reproducir_musica():
	if not reproductor.playing:
		reproductor.play()


func detener_musica():
	if reproductor.playing:
		reproductor.stop()
