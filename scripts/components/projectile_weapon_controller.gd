extends RefCounted

const PROJECTILE_SCENE: PackedScene = preload("res://scenes/bala.tscn")

const CONFIGURACION_ARMAS := {
	"usp": {
		"bala": "res://assets/sprites/balas/BalasUsp.png",
		"cadencia": 0.32, "velocidad": 720.0, "dano": 6,
		"empuje": 65.0, "radio": 3.0, "escala": 0.65, "perdigones": 1,
		"dispersion": 0.0, "capacidad": 36
	},
	"desert": {
		"bala": "res://assets/sprites/balas/BalasDesert.png",
		"cadencia": 0.42, "velocidad": 820.0, "dano": 9,
		"empuje": 100.0, "radio": 4.0, "escala": 0.8, "perdigones": 1,
		"dispersion": 0.0, "capacidad": 24
	},
	"escopeta": {
		"bala": "res://assets/sprites/balas/BalasEscopeta.png",
		"cadencia": 0.85, "velocidad": 640.0, "dano": 3,
		"empuje": 90.0, "radio": 3.0, "escala": 0.65, "perdigones": 5,
		"dispersion": 0.24, "capacidad": 24
	},
	"m4a1": {
		"bala": "res://assets/sprites/balas/BalasM4a1.png",
		"cadencia": 0.12, "velocidad": 900.0, "dano": 3,
		"empuje": 48.0, "radio": 3.0, "escala": 0.7, "perdigones": 1,
		"dispersion": 0.0, "capacidad": 120
	},
	"miniusi": {
		"bala": "res://assets/sprites/balas/BalasMiniusi.png",
		"cadencia": 0.075, "velocidad": 820.0, "dano": 2,
		"empuje": 35.0, "radio": 2.5, "escala": 0.6, "perdigones": 1,
		"dispersion": 0.0, "capacidad": 150
	},
	"snyper": {
		"bala": "res://assets/sprites/balas/BalasSnyper.png",
		"cadencia": 1.1, "velocidad": 1250.0, "dano": 14,
		"empuje": 180.0, "radio": 4.0, "escala": 0.9, "perdigones": 1,
		"dispersion": 0.0, "capacidad": 12
	},
	"basuca": {
		"bala": "res://assets/sprites/balas/BalasBasuca.png",
		"cadencia": 1.25, "velocidad": 460.0, "dano": 20,
		"empuje": 220.0, "radio": 7.0, "escala": 1.0, "perdigones": 1,
		"dispersion": 0.0, "capacidad": 6
	},
	"lanzallamas": {
		"bala": "res://assets/sprites/balas/BalasLanzallama.png",
		"cadencia": 0.06, "velocidad": 360.0, "dano": 1,
		"empuje": 18.0, "radio": 3.5, "escala": 0.7, "perdigones": 1,
		"dispersion": 0.08, "capacidad": 180
	}
}

var _dueno: Danable
var _tiempo_hasta_disparo := 0.0


func _init(dueno: Danable) -> void:
	_dueno = dueno


static func obtener_capacidad(nombre_arma: String) -> int:
	var clave := nombre_arma.to_lower()
	if not CONFIGURACION_ARMAS.has(clave):
		return 0
	return int(CONFIGURACION_ARMAS[clave]["capacidad"])


func procesar(
	delta: float,
	nombre_arma: String,
	mantener_disparo: bool,
	direccion: Vector2
) -> bool:
	_tiempo_hasta_disparo = maxf(_tiempo_hasta_disparo - delta, 0.0)
	if not mantener_disparo or _tiempo_hasta_disparo > 0.0:
		return false
	var clave := nombre_arma.to_lower()
	if not CONFIGURACION_ARMAS.has(clave):
		return false
	var configuracion: Dictionary = CONFIGURACION_ARMAS[clave]
	var textura := load(configuracion["bala"]) as Texture2D
	if textura == null:
		push_warning("No se encontró el sprite de bala para " + nombre_arma)
		return false
	if direccion.length_squared() < 0.001:
		direccion = Vector2.RIGHT
	direccion = direccion.normalized()
	var escena := _dueno.get_tree().current_scene
	if escena == null:
		return false
	var cantidad: int = int(configuracion["perdigones"])
	var dispersion: float = float(configuracion["dispersion"])
	for indice in range(cantidad):
		var desplazamiento_angular := 0.0
		if cantidad > 1:
			desplazamiento_angular = lerpf(
				-dispersion,
				dispersion,
				float(indice) / float(cantidad - 1)
			)
		elif dispersion > 0.0:
			desplazamiento_angular = randf_range(-dispersion, dispersion)
		var direccion_bala := direccion.rotated(desplazamiento_angular)
		var bala := PROJECTILE_SCENE.instantiate()
		var posicion_muzzle := _dueno.global_position + Vector2(
			direccion_bala.x * 20.0,
			-12.0 + direccion_bala.y * 8.0
		)
		bala.call(
			"configurar",
			_dueno,
			posicion_muzzle,
			direccion_bala,
			textura,
			float(configuracion["velocidad"]),
			int(configuracion["dano"]),
			float(configuracion["empuje"]),
			float(configuracion["radio"]),
			float(configuracion["escala"])
		)
		escena.call_deferred("add_child", bala)
	_tiempo_hasta_disparo = float(configuracion["cadencia"])
	return true
