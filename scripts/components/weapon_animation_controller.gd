extends RefCounted

const CONFIGURACION_ANIMACIONES := {
	"usp": ["Usp", "Usp", "usp"],
	"desert": ["Desert", "Desert", "desert"],
	"escopeta": ["Escopeta", "Escopeta", "escopeta"],
	"m4a1": ["M4a1", "M4a1", "m4a1"],
	"miniusi": ["MiniUsi", "Miniusi", "miniUsi"],
	"snyper": ["Snyper", "Snyper", "snyper"],
	"basuca": ["Basuca", "Basuca", "basuca"],
	"lanzallamas": ["Lanzallama", "Lanzallama", "lanzallama"]
}

var _sprite: AnimatedSprite2D


func _init(sprite: AnimatedSprite2D) -> void:
	_sprite = sprite


func esta_disparando() -> bool:
	return _sprite.animation == "shoot" and _sprite.is_playing()


func mostrar_pose_apuntado(nombre_arma: String, variante: String) -> bool:
	if not _cargar_animacion_disparo(nombre_arma, variante):
		return false
	_sprite.animation = "shoot"
	_sprite.frame = 0
	_sprite.stop()
	return true


func reproducir_disparo(nombre_arma: String, variante: String) -> bool:
	if esta_disparando():
		return true
	if not _cargar_animacion_disparo(nombre_arma, variante):
		return false
	_sprite.play("shoot")
	return true


func _cargar_animacion_disparo(nombre_arma: String, variante: String) -> bool:
	var clave := nombre_arma.to_lower()
	if not CONFIGURACION_ANIMACIONES.has(clave):
		return false
	var datos: Array = CONFIGURACION_ANIMACIONES[clave]
	var carpeta := String(datos[0])
	var nombre_variante := String(datos[1]) + variante
	var prefijo := String(datos[2])
	if clave == "miniusi":
		nombre_variante = "Miniusi" + variante
	var ruta_base := "res://assets/sprites/weaponAttacks/disparar%s/disparar%s/%s" % [
		carpeta,
		nombre_variante,
		prefijo
	]
	var nombre_animacion := "shoot"
	if _sprite.sprite_frames.has_animation(nombre_animacion):
		_sprite.sprite_frames.remove_animation(nombre_animacion)
	_sprite.sprite_frames.add_animation(nombre_animacion)
	_sprite.sprite_frames.set_animation_speed(nombre_animacion, 12.0)
	_sprite.sprite_frames.set_animation_loop(nombre_animacion, false)
	for indice in range(1, 4):
		var sufijo := "(%d)" % indice if clave == "m4a1" else str(indice)
		var textura := load(ruta_base + sufijo + ".png") as Texture2D
		if textura == null:
			_sprite.sprite_frames.remove_animation(nombre_animacion)
			push_warning("No se encontró el sprite de disparo: " + ruta_base + sufijo + ".png")
			return false
		_sprite.sprite_frames.add_frame(nombre_animacion, textura)
	return true
