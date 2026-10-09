extends RefCounted

var _sprite: AnimatedSprite2D


func _init(sprite: AnimatedSprite2D) -> void:
	_sprite = sprite


func configurar_bucle(nombre: String, debe_repetir: bool) -> void:
	if _sprite.sprite_frames == null:
		return
	if _sprite.sprite_frames.has_animation(nombre):
		_sprite.sprite_frames.set_animation_loop(nombre, debe_repetir)


func reproducir(
	nombre: String,
	hacia_atras: bool = false,
	restablecer_velocidad: bool = true
) -> void:
	if _sprite.sprite_frames == null:
		return
	if not _sprite.sprite_frames.has_animation(nombre):
		return

	if restablecer_velocidad:
		_sprite.speed_scale = 1.0

	if _sprite.animation == nombre and _sprite.is_playing():
		return

	if hacia_atras:
		_sprite.play_backwards(nombre)
	else:
		_sprite.play(nombre)


func reproducir_locomocion(
	en_suelo: bool,
	direccion: float,
	agachado: bool,
	corriendo: bool,
	usar_trote_si_falta_run: bool = false
) -> void:
	if not en_suelo:
		reproducir("jump")
	elif agachado:
		reproducir("ducking")
	elif not is_zero_approx(direccion):
		if corriendo:
			if usar_trote_si_falta_run and (
				_sprite.sprite_frames == null
				or not _sprite.sprite_frames.has_animation("run")
			):
				reproducir("trot")
			else:
				reproducir("run")
		else:
			reproducir("trot")
	else:
		reproducir("standing")
