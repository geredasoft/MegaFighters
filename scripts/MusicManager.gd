extends Node

var musica_niveles = preload("res://assets/audio/musica_niveles.ogg")

var reproductor: AudioStreamPlayer


func _ready():
	reproductor = AudioStreamPlayer.new()
	reproductor.stream = musica_niveles
	reproductor.autoplay = false
	# Mantiene la música en segundo plano para que destaquen los efectos de armas.
	reproductor.volume_db = -18
	
	add_child(reproductor)


func reproducir_musica():
	if not reproductor.playing:
		reproductor.play()


func detener_musica():
	if reproductor.playing:
		reproductor.stop()
