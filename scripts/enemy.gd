extends Danable

const EnemyWorldSensorScript = preload(
	"res://scripts/components/enemy_world_sensor.gd"
)
const SpriteAnimationControllerScript = preload(
	"res://scripts/components/sprite_animation_controller.gd"
)
const EnemySeparationControllerScript = preload(
	"res://scripts/components/enemy_separation_controller.gd"
)
const EnemyPlatformControllerScript = preload(
	"res://scripts/components/enemy_platform_controller.gd"
)
const CombatHitProcessorScript = preload(
	"res://scripts/components/combat_hit_processor.gd"
)
const CharacterPhysicsControllerScript = preload(
	"res://scripts/components/character_physics_controller.gd"
)
const EnemyPlatformDecisionControllerScript = preload(
	"res://scripts/components/enemy_platform_decision_controller.gd"
)
const EnemyCombatControllerScript = preload(
	"res://scripts/components/enemy_combat_controller.gd"
)
const EnemyPlatformMotionControllerScript = preload(
	"res://scripts/components/enemy_platform_motion_controller.gd"
)
const EnemyNavigationControllerScript = preload(
	"res://scripts/components/enemy_navigation_controller.gd"
)
const EnemyAttackControllerScript = preload(
	"res://scripts/components/enemy_attack_controller.gd"
)
const EnemyStateDecisionControllerScript = preload(
	"res://scripts/components/enemy_state_decision_controller.gd"
)
const EnemyLifecycleControllerScript = preload(
	"res://scripts/components/enemy_lifecycle_controller.gd"
)
const EnemyPortalControllerScript = preload(
	"res://scripts/components/enemy_portal_controller.gd"
)


# =========================================================
# ENEMY: composition root para estado, señales y API del actor.
# =========================================================
#
# Los componentes encapsulan navegación, combate, percepción, plataformas,
# portales y ciclo de vida. Aquí se conectan a los nodos y al contrato Danable.
#
# =========================================================



# =========================================================
# 01. CONFIGURACIÓN - MOVIMIENTO
# =========================================================

const VELOCIDAD_TROTE: float = 120.0
const VELOCIDAD_CARRERA: float = 220.0

const ACELERACION: float = 850.0
const DESACELERACION: float = 1100.0

const FUERZA_SALTO: float = -490.0
const GRAVEDAD: float = 1200.0


# =========================================================
# 02. CONFIGURACIÓN - IA / DETECCIÓN
# =========================================================

const DISTANCIA_DETECCION: float = 380.0
const DIFERENCIA_VERTICAL_MAXIMA: float = 130.0

const DISTANCIA_ATAQUE: float = 58.0
const DISTANCIA_COMBATE_MINIMA: float = 42.0
const DISTANCIA_RETROCESO: float = 25.0


# =========================================================
# SEPARACIÓN ENTRE ENEMIGOS
# =========================================================

const DISTANCIA_SEPARACION_ENEMY: float = 48.0

const FUERZA_SEPARACION_ENEMY: float = 180.0


# =========================================================
# 03. CONFIGURACIÓN - PATRULLA
# =========================================================

const DISTANCIA_PATRULLA: float = 160.0
const TIEMPO_ESPERA_PATRULLA: float = 1.2


# =========================================================
# 04. CONFIGURACIÓN - DECISIONES DE IA
# =========================================================

const TIEMPO_RECUPERACION_ATAQUE: float = 0.75
const TIEMPO_VIENTO_ATAQUE: float = 0.18
const TIEMPO_PERDIDA_JUGADOR: float = 1.0

const DISTANCIA_SALTO_HORIZONTAL: float = 100.0


# =========================================================
# 05. CONFIGURACIÓN - ATAQUE
# =========================================================

const FRAME_ATAQUE_INICIO: int = 2
const FRAME_ATAQUE_FIN: int = 3

const IMPULSO_ATAQUE: float = 85.0
const FRENADO_ATAQUE: float = 900.0

const DAÑO_ATAQUE: int = 10

const FUERZA_EMPUJE_ATAQUE: float = 1.0
const FUERZA_EMPUJE_VERTICAL: float = -120.0

const HITBOX_OFFSET_X: float = 20.0
const HITBOX_OFFSET_Y: float = -2.0


# =========================================================
# 06. CONFIGURACIÓN - PLATAFORMAS MÓVILES
# =========================================================

const DISTANCIA_RADAR_PLATAFORMA: float = 220.0
const DISTANCIA_VERTICAL_PLATAFORMA: float = 130.0

const COOLDOWN_REINTENTO_PLATAFORMA: float = 3.0

const ALCANCE_DESEMBARCO: float = 75.0
const ALCANCE_SALTO_DESEMBARCO: float = 110.0

const PROFUNDIDAD_DESEMBARCO: float = 45.0
const PROFUNDIDAD_SALTO_DESEMBARCO: float = 95.0


# =========================================================
# 07. CONFIGURACIÓN - PORTAL
# =========================================================

const DURACION_INERCIA_PORTAL: float = 0.45


# =========================================================
# 08. CONFIGURACIÓN - KNOCKBACK
# =========================================================

const FUERZA_KNOCKBACK_HORIZONTAL: float = 320.0
const FUERZA_KNOCKBACK_VERTICAL: float = -180.0

# =========================================================
# 09. CONFIGURACIÓN EXPORTADA
# =========================================================

@export_category("IA")

@export var perseguir_jugador: bool = true

@export_flags_2d_physics var mascara_terreno: int = 1


# =========================================================
# 10. REFERENCIAS DE NODOS
# =========================================================

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

@onready var _controlador_animacion = SpriteAnimationControllerScript.new(sprite)

@onready var hitbox_ataque: Area2D = $HitboxAtaque

@onready var collision_hitbox: CollisionShape2D = (
	$HitboxAtaque/CollisionShape2D
)

# =========================================================
# 11. MÁQUINA DE ESTADOS
# =========================================================

enum Estado {
	PATRULLANDO,
	ESPERA_PATRULLA,
	PERSEGUIR,
	POSICIONARSE,
	ANTICIPANDO_ATAQUE,
	ATACANDO,
	RECUPERACION,
	INTERCEPTANDO_PLATAFORMA,
	EN_PLATAFORMA,
	MUERTO
}

var estado: Estado = Estado.PATRULLANDO


# =========================================================
# 12. REFERENCIA AL PLAYER
# =========================================================

var jugador: CharacterBody2D = null

var _sensor_entorno
var _controlador_decision_plataforma
var _controlador_movimiento_plataforma
var _controlador_combate
var _controlador_navegacion
var _controlador_ataque
var _controlador_decisiones_estado
var _controlador_ciclo_vida
var _controlador_portal

@onready var _controlador_separacion = EnemySeparationControllerScript.new(self)

@onready var _controlador_plataformas = EnemyPlatformControllerScript.new(self)

@onready var _procesador_golpes = CombatHitProcessorScript.new()

@onready var _controlador_fisica = CharacterPhysicsControllerScript.new(self)


# =========================================================
# 13. TIMERS / CONTADORES
# =========================================================

var timer_patrulla: float = 0.0
var timer_inercia_portal: float = 0.0
var timer_cooldown_plataforma: float = 0.0

var timer_perdida_jugador: float = 0.0


# =========================================================
# 14. DATOS DE PATRULLA
# =========================================================

var direccion_patrulla: float = 1.0
var punto_origen_x: float = 0.0


# =========================================================
# 15. DATOS DE PLATAFORMAS
# =========================================================

var plataforma_actual: AnimatableBody2D = null
var plataforma_objetivo: AnimatableBody2D = null


# =========================================================
# 16. DATOS DE FÍSICA / ENTORNO
# =========================================================

var gravedad_actual: float = GRAVEDAD
var damping_entorno: float = 0.0

var posicion_inicial: Vector2 = Vector2.ZERO


# =========================================================
# 17. DATOS DE KNOCKBACK
# =========================================================

var velocidad_knockback: float = 0.0


# =========================================================
# 19. CICLO DE VIDA - READY
# =========================================================

func _ready() -> void:

	_sensor_entorno = EnemyWorldSensorScript.new(
		self,
		mascara_terreno
	)
	_controlador_decisiones_estado = EnemyStateDecisionControllerScript.new(
		self,
		_sensor_entorno,
		{
			"distancia_deteccion": DISTANCIA_DETECCION,
			"diferencia_vertical_maxima": DIFERENCIA_VERTICAL_MAXIMA,
			"tiempo_perdida": TIEMPO_PERDIDA_JUGADOR,
			"distancia_ataque": DISTANCIA_ATAQUE,
			"diferencia_ataque": 45.0,
			"distancia_combate_minima": DISTANCIA_COMBATE_MINIMA
		}
	)
	_controlador_decision_plataforma = EnemyPlatformDecisionControllerScript.new(
		self,
		_sensor_entorno,
		_controlador_plataformas
	)
	_controlador_movimiento_plataforma = EnemyPlatformMotionControllerScript.new(
		self,
		sprite,
		_controlador_decision_plataforma,
		Callable(self, "actualizar_direccion_hitbox"),
		Callable(self, "actualizar_animacion_movimiento"),
		Callable(self, "reproducir_animacion")
	)
	_controlador_combate = EnemyCombatControllerScript.new(
		self,
		sprite,
		hitbox_ataque,
		collision_hitbox,
		_procesador_golpes,
		{
			"frame_start": FRAME_ATAQUE_INICIO,
			"frame_end": FRAME_ATAQUE_FIN,
			"damage": DAÑO_ATAQUE,
			"horizontal_knockback": FUERZA_EMPUJE_ATAQUE,
			"vertical_knockback": FUERZA_EMPUJE_VERTICAL,
			"hitbox_offset_x": HITBOX_OFFSET_X,
			"hitbox_offset_y": HITBOX_OFFSET_Y
		}
	)
	_controlador_navegacion = EnemyNavigationControllerScript.new(
		self,
		sprite,
		_sensor_entorno,
		_controlador_separacion,
		{
			"animar_movimiento": Callable(self, "actualizar_animacion_movimiento"),
			"reproducir_animacion": Callable(self, "reproducir_animacion"),
			"actualizar_hitbox": Callable(self, "actualizar_direccion_hitbox"),
			"cambiar_estado": Callable(self, "_cambiar_estado_por_nombre"),
			"preparar_ataque": Callable(self, "preparar_ataque"),
			"intentar_interceptar": Callable(self, "_intentar_interceptar_plataforma")
		},
		{
			"distancia_patrulla": DISTANCIA_PATRULLA,
			"tiempo_espera": TIEMPO_ESPERA_PATRULLA,
			"aceleracion": ACELERACION,
			"desaceleracion": DESACELERACION,
			"velocidad_trote": VELOCIDAD_TROTE,
			"velocidad_carrera": VELOCIDAD_CARRERA,
			"fuerza_salto": FUERZA_SALTO,
			"distancia_salto": DISTANCIA_SALTO_HORIZONTAL,
			"distancia_separacion": DISTANCIA_SEPARACION_ENEMY,
			"fuerza_separacion": FUERZA_SEPARACION_ENEMY,
			"distancia_ataque": DISTANCIA_ATAQUE,
			"distancia_combate_minima": DISTANCIA_COMBATE_MINIMA,
			"distancia_retroceso": DISTANCIA_RETROCESO
		}
	)
	_controlador_ataque = EnemyAttackControllerScript.new(
		self,
		sprite,
		_procesador_golpes,
		_controlador_combate,
		{
			"cambiar_estado": Callable(self, "_cambiar_estado_por_nombre"),
			"reproducir_animacion": Callable(self, "reproducir_animacion"),
			"actualizar_hitbox": Callable(self, "actualizar_direccion_hitbox")
		},
		{
			"windup": TIEMPO_VIENTO_ATAQUE,
			"impulso": IMPULSO_ATAQUE,
			"frenado": FRENADO_ATAQUE
		}
	)
	_controlador_ciclo_vida = EnemyLifecycleControllerScript.new(
		self,
		{
			"esta_muerto": Callable(self, "esta_muerto"),
			"cambiar_estado": Callable(self, "_cambiar_estado_por_nombre"),
			"limpiar_knockback": Callable(self, "_limpiar_knockback"),
			"limpiar_plataformas": Callable(self, "_limpiar_plataformas"),
			"limpiar_objetivos": Callable(_procesador_golpes, "limpiar_objetivos"),
			"desactivar_hitbox": Callable(self, "desactivar_hitbox_ataque"),
			"reproducir_animacion": Callable(self, "reproducir_animacion"),
			"restaurar_datos": Callable(self, "_restaurar_datos_iniciales"),
			"actualizar_origen_patrulla": Callable(self, "_actualizar_origen_patrulla"),
			"reiniciar_vida": Callable(self, "reiniciar_vida")
		}
	)

	_configurar_grupo_enemy()
	_configurar_plataformas()
	_configurar_posicion_inicial()
	_controlador_ciclo_vida.establecer_posicion_inicial(posicion_inicial)
	_controlador_portal = EnemyPortalControllerScript.new(
		self,
		sprite,
		_controlador_ataque,
		{
			"limpiar_plataformas": Callable(self, "_limpiar_plataformas"),
			"limpiar_knockback": Callable(self, "_limpiar_knockback"),
			"desactivar_hitbox": Callable(self, "desactivar_hitbox_ataque"),
			"cambiar_estado": Callable(self, "_cambiar_estado_por_nombre"),
			"actualizar_origen_patrulla": Callable(self, "_actualizar_origen_patrulla"),
			"establecer_inercia": Callable(self, "_establecer_inercia_portal"),
			"reproducir_animacion": Callable(self, "reproducir_animacion")
		},
		DURACION_INERCIA_PORTAL
	)
	_configurar_sprite()
	_configurar_animaciones()
	_configurar_senales()
	_configurar_hitbox()
	buscar_jugador()


# =========================================================
# 20. CONFIGURACIÓN INICIAL
# =========================================================

func _configurar_grupo_enemy() -> void:

	add_to_group("enemy")


func _configurar_plataformas() -> void:

	platform_on_leave = (
		PlatformOnLeave.PLATFORM_ON_LEAVE_ADD_VELOCITY
	)


func _configurar_posicion_inicial() -> void:

	posicion_inicial = global_position
	punto_origen_x = global_position.x


func _configurar_sprite() -> void:

	sprite.scale = Vector2(2.0, 2.0)

	reproducir_animacion("standing")


func _configurar_animaciones() -> void:
	_controlador_animacion.configurar_bucle("attack", false)
	_controlador_animacion.configurar_bucle("fall_on_ground", false)


func _configurar_senales() -> void:

	if not sprite.animation_finished.is_connected(
		_on_animation_finished
	):

		sprite.animation_finished.connect(
			_on_animation_finished
	)

	if not hitbox_ataque.area_entered.is_connected(
		_on_hitbox_ataque_area_entered
	):

		hitbox_ataque.area_entered.connect(
			_on_hitbox_ataque_area_entered
	)


func _configurar_hitbox() -> void:

	desactivar_hitbox_ataque()
	actualizar_direccion_hitbox()


# =========================================================
# 21. PHYSICS PROCESS
# =========================================================

func _physics_process(delta: float) -> void:

	_actualizar_timers(delta)
	_aplicar_gravedad(delta)
	_procesar_knockback(delta)

	# -----------------------------------------------------
	# KNOCKBACK
	# -----------------------------------------------------

	if _esta_recibiendo_knockback():

		_aplicar_damping(delta)
		move_and_slide()

		return

	# -----------------------------------------------------
	# BUSCAR PLAYER
	# -----------------------------------------------------

	if jugador == null or not is_instance_valid(jugador):

		buscar_jugador()

	# -----------------------------------------------------
	# IA
	# -----------------------------------------------------

	if estado != Estado.MUERTO:

		evaluar_transiciones()
		procesar_comportamiento(delta)

	# -----------------------------------------------------
	# DAMPING
	# -----------------------------------------------------

	_aplicar_damping(delta)

	# -----------------------------------------------------
	# MOVIMIENTO FÍSICO
	# -----------------------------------------------------

	move_and_slide()


# =========================================================
# 22. TIMERS
# =========================================================

func _actualizar_timers(delta: float) -> void:

	_controlador_ataque.actualizar_timers(delta)

	timer_inercia_portal = maxf(
		timer_inercia_portal - delta,
		0.0
	)

	timer_cooldown_plataforma = maxf(
		timer_cooldown_plataforma - delta,
		0.0
	)

	if timer_perdida_jugador > 0.0:

		timer_perdida_jugador = maxf(
			timer_perdida_jugador - delta,
			0.0
		)


# =========================================================
# 23. FÍSICA - GRAVEDAD
# =========================================================

func _aplicar_gravedad(delta: float) -> void:
	_controlador_fisica.aplicar_gravedad(delta, gravedad_actual)


# =========================================================
# 24. FÍSICA - DAMPING
# =========================================================

func _aplicar_damping(delta: float) -> void:
	_controlador_fisica.aplicar_damping(delta, damping_entorno)


# =========================================================
# 25. KNOCKBACK - PROCESAMIENTO
# =========================================================

func _procesar_knockback(delta: float) -> void:
	if _esta_recibiendo_knockback():
		velocidad_knockback = _controlador_fisica.procesar_knockback(
			velocidad_knockback,
			DESACELERACION,
			delta
		)


func _esta_recibiendo_knockback() -> bool:
	return _controlador_fisica.esta_recibiendo_knockback(
		velocidad_knockback
	)


# =========================================================
# 26. PORTAL
# =========================================================

func aplicar_efecto_portal(
	nueva_posicion: Vector2,
	nueva_velocidad: Vector2
) -> void:
	direccion_patrulla = _controlador_portal.aplicar_efecto(
		nueva_posicion, nueva_velocidad, direccion_patrulla
	)


func _establecer_inercia_portal(duracion: float) -> void:
	timer_inercia_portal = duracion


# =========================================================
# 27. IA - TRANSICIONES
# =========================================================

func evaluar_transiciones() -> void:
	actualizar_plataforma_actual()
	var resultado: Dictionary = _controlador_decisiones_estado.evaluar(
		_obtener_nombre_estado(),
		jugador,
		perseguir_jugador,
		timer_inercia_portal,
		timer_perdida_jugador,
		plataforma_actual,
		_controlador_ataque.obtener_cooldown()
	)
	timer_perdida_jugador = float(resultado["timer_perdida"])
	if bool(resultado["reiniciar_origen"]):
		punto_origen_x = global_position.x
	if bool(resultado["preparar_ataque"]):
		preparar_ataque()
	elif not String(resultado["estado"]).is_empty():
		_cambiar_estado_por_nombre(String(resultado["estado"]))


func _obtener_nombre_estado() -> String:
	match estado:
		Estado.ANTICIPANDO_ATAQUE:
			return "anticipando"
		Estado.ATACANDO:
			return "atacando"
		Estado.RECUPERACION:
			return "recuperacion"
		Estado.PERSEGUIR:
			return "perseguir"
		Estado.POSICIONARSE:
			return "posicionarse"
		_:
			return "otro"


# =========================================================
# 28. IA - COMPORTAMIENTO PRINCIPAL
# =========================================================

func procesar_comportamiento(delta: float) -> void:

	match estado:

		Estado.PATRULLANDO:
			ejecutar_patrulla(delta)

		Estado.ESPERA_PATRULLA:
			ejecutar_espera_patrulla(delta)

		Estado.PERSEGUIR:
			ejecutar_persecucion(delta)

		Estado.POSICIONARSE:
			ejecutar_posicionamiento(delta)

		Estado.ANTICIPANDO_ATAQUE:
			ejecutar_anticipacion(delta)

		Estado.ATACANDO:
			ejecutar_ataque(delta)

		Estado.RECUPERACION:
			ejecutar_recuperacion(delta)

		Estado.INTERCEPTANDO_PLATAFORMA:
			ejecutar_intercepcion_plataforma(delta)

		Estado.EN_PLATAFORMA:
			ejecutar_en_plataforma(delta)

		Estado.MUERTO:
			pass


# =========================================================
# 29. IA - PATRULLA
# =========================================================

func ejecutar_patrulla(delta: float) -> void:
	var resultado: Dictionary = _controlador_navegacion.ejecutar_patrulla(
		delta, direccion_patrulla, punto_origen_x, timer_patrulla
	)
	if resultado["estado"] == "espera":
		estado = Estado.ESPERA_PATRULLA
		timer_patrulla = float(resultado["timer"])


# =========================================================
# 30. IA - ESPERA DE PATRULLA
# =========================================================

func ejecutar_espera_patrulla(delta: float) -> void:
	var resultado: Dictionary = _controlador_navegacion.ejecutar_espera(
		delta, timer_patrulla, punto_origen_x, direccion_patrulla
	)
	timer_patrulla = float(resultado["timer"])
	if resultado["estado"] == "patrulla":
		direccion_patrulla = float(resultado["direccion"])
		punto_origen_x = float(resultado["origen_x"])
		estado = Estado.PATRULLANDO

# =========================================================
# SEPARACIÓN - OBTENER ENEMIGOS CERCANOS
# =========================================================

func obtener_enemigos_cercanos() -> Array[Node2D]:
	return _controlador_separacion.obtener_enemigos_cercanos(
		DISTANCIA_SEPARACION_ENEMY
	)

# =========================================================
# SEPARACIÓN - CALCULAR FUERZA
# =========================================================

func calcular_separacion_enemigos() -> Vector2:
	return _controlador_separacion.calcular_separacion(
		DISTANCIA_SEPARACION_ENEMY,
		FUERZA_SEPARACION_ENEMY
	)

# =========================================================
# 31. IA - PERSECUCIÓN
# =========================================================

func ejecutar_persecucion(delta: float) -> void:
	_controlador_navegacion.ejecutar_persecucion(delta, jugador)

# =========================================================
# 32. IA - POSICIONAMIENTO DE COMBATE
# =========================================================

func ejecutar_posicionamiento(delta: float) -> void:
	_controlador_navegacion.ejecutar_posicionamiento(
		delta, jugador, _controlador_ataque.obtener_cooldown()
	)


func _cambiar_estado_por_nombre(nombre_estado: String) -> void:
	match nombre_estado:
		"anticipando":
			estado = Estado.ANTICIPANDO_ATAQUE
		"atacando":
			estado = Estado.ATACANDO
		"recuperacion":
			estado = Estado.RECUPERACION
		"perseguir":
			estado = Estado.PERSEGUIR
		"posicionarse":
			estado = Estado.POSICIONARSE
		"en_plataforma":
			estado = Estado.EN_PLATAFORMA
		"patrulla", "patrullando":
			estado = Estado.PATRULLANDO
		"muerto":
			estado = Estado.MUERTO


func _limpiar_knockback() -> void:
	velocidad_knockback = 0.0


func _limpiar_plataformas() -> void:
	plataforma_actual = null
	plataforma_objetivo = null


func _restaurar_datos_iniciales() -> void:
	velocidad_knockback = 0.0
	gravedad_actual = GRAVEDAD
	timer_patrulla = 0.0
	timer_inercia_portal = 0.0
	timer_cooldown_plataforma = 0.0
	timer_perdida_jugador = 0.0
	_controlador_ataque.reiniciar()


func _actualizar_origen_patrulla() -> void:
	punto_origen_x = global_position.x

# =========================================================
# 33. COMBATE - PREPARACIÓN DE ATAQUE
# =========================================================

func preparar_ataque() -> void:
	_controlador_ataque.preparar(jugador)


# =========================================================
# 34. COMBATE - ANTICIPACIÓN
# =========================================================

func ejecutar_anticipacion(delta: float) -> void:
	_controlador_ataque.ejecutar_anticipacion(
		delta, DESACELERACION, jugador
	)


# =========================================================
# 35. COMBATE - INICIAR ATAQUE
# =========================================================

func iniciar_ataque() -> void:
	if estado == Estado.MUERTO:
		return
	_controlador_ataque.iniciar(jugador)


# =========================================================
# 36. COMBATE - EJECUTAR ATAQUE
# =========================================================

func ejecutar_ataque(delta: float) -> void:
	_controlador_ataque.ejecutar_ataque(delta)


# =========================================================
# 37. COMBATE - VENTANA DE ATAQUE
# =========================================================

func _actualizar_ventana_ataque() -> void:
	_controlador_combate.actualizar_ventana_ataque()


func activar_hitbox_ataque() -> void:
	_controlador_combate.activar_hitbox_ataque()


func desactivar_hitbox_ataque() -> void:
	_controlador_combate.desactivar_hitbox_ataque()


func actualizar_direccion_hitbox() -> void:
	_controlador_combate.actualizar_direccion_hitbox()


func _on_hitbox_ataque_area_entered(area: Area2D) -> void:
	if _controlador_combate.esta_activo():
		_controlador_combate.procesar_hurtbox_player(area)


func procesar_hurtbox_player(area: Area2D) -> void:
	_controlador_combate.procesar_hurtbox_player(area)


func _procesar_hurtboxes_dentro_del_hitbox() -> void:
	_controlador_combate.procesar_hurtboxes_superpuestas()

func ejecutar_recuperacion(delta: float) -> void:
	_controlador_ataque.ejecutar_recuperacion(
		delta,
		DESACELERACION,
		jugador,
		puede_ver_al_jugador()
	)
	if estado == Estado.PATRULLANDO:
		punto_origen_x = global_position.x

# =========================================================
# 43. COMBATE - FIN DE ANIMACIÓN
# =========================================================

func _on_animation_finished() -> void:

	match sprite.animation:

		"attack":
			_controlador_ataque.finalizar_animacion_ataque(
				TIEMPO_RECUPERACION_ATAQUE
			)

# =========================================================
# 45. PLATAFORMAS - INTERCEPCIÓN
# =========================================================

func _intentar_interceptar_plataforma(puede_ver: bool) -> void:
	if estado not in [Estado.PATRULLANDO, Estado.PERSEGUIR]:
		return
	if not is_on_floor() or timer_cooldown_plataforma > 0.0:
		return

	var decision: Dictionary = _controlador_decision_plataforma.decidir_intercepcion(
		puede_ver,
		jugador,
		direccion_patrulla,
		DISTANCIA_RADAR_PLATAFORMA,
		DISTANCIA_VERTICAL_PLATAFORMA,
		0.65
	)

	if decision["rechazada_por_azar"]:
		timer_cooldown_plataforma = COOLDOWN_REINTENTO_PLATAFORMA
		return

	var plataforma := decision["plataforma"] as AnimatableBody2D
	if plataforma != null:
		plataforma_objetivo = plataforma
		estado = Estado.INTERCEPTANDO_PLATAFORMA

func ejecutar_intercepcion_plataforma(delta: float) -> void:
	if plataforma_objetivo == null or not is_instance_valid(plataforma_objetivo):
		plataforma_objetivo = null
		estado = Estado.PERSEGUIR
		return

	_controlador_movimiento_plataforma.ejecutar_intercepcion(
		plataforma_objetivo,
		delta,
		FUERZA_SALTO,
		VELOCIDAD_CARRERA,
		VELOCIDAD_TROTE,
		ACELERACION
	)

func ejecutar_en_plataforma(delta: float) -> void:
	if plataforma_actual == null:
		estado = (
			Estado.PERSEGUIR
			if _puede_perseguir_jugador()
			else Estado.PATRULLANDO
		)
		return

	var desembarco_realizado: bool = _controlador_movimiento_plataforma.ejecutar_en_plataforma(
		obtener_velocidad_plataforma(plataforma_actual),
		obtener_direcciones_desembarco(),
		delta,
		ALCANCE_DESEMBARCO,
		PROFUNDIDAD_DESEMBARCO,
		ALCANCE_SALTO_DESEMBARCO,
		PROFUNDIDAD_SALTO_DESEMBARCO,
		FUERZA_SALTO,
		VELOCIDAD_CARRERA,
		DESACELERACION
	)
	if not desembarco_realizado:
		return

	plataforma_actual = null
	plataforma_objetivo = null
	timer_cooldown_plataforma = COOLDOWN_REINTENTO_PLATAFORMA
	punto_origen_x = global_position.x
	estado = (
		Estado.PERSEGUIR
		if _puede_perseguir_jugador()
		else Estado.PATRULLANDO
	)

# 48. PLATAFORMAS - DIRECCIONES DE DESEMBARCO
# =========================================================

func obtener_direcciones_desembarco() -> Array[float]:
	var jugador_visible := jugador != null and puede_ver_al_jugador()
	var posicion_jugador := global_position
	if jugador_visible:
		posicion_jugador = jugador.global_position

	var direcciones: Array[float] = _controlador_decision_plataforma.call(
		"obtener_direcciones_desembarco",
		global_position,
		posicion_jugador,
		jugador_visible
	)
	return direcciones


# =========================================================
# 49. PLATAFORMAS - VELOCIDAD
# =========================================================

func obtener_velocidad_plataforma(
	plataforma: AnimatableBody2D
) -> Vector2:
	return _controlador_plataformas.obtener_velocidad(plataforma)


# =========================================================
# 50. PLATAFORMAS - DETECTAR ACTUAL
# =========================================================

func actualizar_plataforma_actual() -> void:
	plataforma_actual = _controlador_plataformas.detectar_plataforma_bajo_agente(
		mascara_terreno
	)


# =========================================================
# 51. PLATAFORMAS - BUSCAR CERCANA
# =========================================================

func buscar_plataforma_cercana() -> AnimatableBody2D:
	return _controlador_plataformas.buscar_plataforma_cercana(
		DISTANCIA_RADAR_PLATAFORMA,
		DISTANCIA_VERTICAL_PLATAFORMA
	)


# =========================================================
# 52. PERCEPCIÓN - PLAYER
# =========================================================

func puede_ver_al_jugador() -> bool:
	return _sensor_entorno.puede_ver_objetivo(
		jugador,
		DISTANCIA_DETECCION,
		DIFERENCIA_VERTICAL_MAXIMA
	)


# =========================================================
# 53. ENTORNO - SUELO
# =========================================================

func hay_suelo(
	direccion: float,
	avance: float
) -> bool:
	return _sensor_entorno.hay_suelo(direccion, avance)


# =========================================================
# 54. ENTORNO - SUELO ESTÁTICO
# =========================================================

func hay_suelo_estatico(
	direccion: float,
	avance: float,
	profundidad: float = 38.0
) -> bool:
	return _sensor_entorno.hay_suelo_estatico(
		direccion,
		avance,
		profundidad
	)


# =========================================================
# 55. ENTORNO - PARED
# =========================================================

func hay_pared(
	direccion: float,
	distancia: float
) -> bool:
	return _sensor_entorno.hay_pared(direccion, distancia)


# =========================================================
# 56. ENTORNO - ESPACIO PARA SALTAR
# =========================================================

func hay_espacio_para_saltar(
	direccion: float
) -> bool:
	return _sensor_entorno.hay_espacio_para_saltar(direccion)


# =========================================================
# 57. PLAYER - BÚSQUEDA
# =========================================================

func buscar_jugador() -> void:
	jugador = _sensor_entorno.buscar_jugador(get_tree())


# =========================================================
# 58. PLAYER - VALIDAR PERSECUCIÓN
# =========================================================

func _puede_perseguir_jugador() -> bool:

	return (
		jugador != null
		and is_instance_valid(jugador)
		and perseguir_jugador
		and puede_ver_al_jugador()
	)


# =========================================================
# 59. ANIMACIONES - MOVIMIENTO
# =========================================================

func actualizar_animacion_movimiento(
	corriendo: bool
) -> void:
	var direccion: float = signf(velocity.x) if absf(velocity.x) > 10.0 else 0.0
	_controlador_animacion.reproducir_locomocion(
		is_on_floor(), direccion, false, corriendo, true
	)


# =========================================================
# 60. ANIMACIONES - REPRODUCIR
# =========================================================

func reproducir_animacion(
	nombre: String
) -> void:
	_controlador_animacion.reproducir(
		nombre,
		false,
		false
	)


# =========================================================
# 61. CICLO DE VIDA - MUERTE
# =========================================================

func morir() -> void:
	_controlador_ciclo_vida.morir()


# =========================================================
# 62. CICLO DE VIDA - ESTADO MUERTO
# =========================================================

func esta_muerto() -> bool:

	return estado == Estado.MUERTO


# =========================================================
# 63. CICLO DE VIDA - REINICIO
# =========================================================

func reiniciar() -> void:
	_controlador_ciclo_vida.reiniciar()


# =========================================================
# 64. KNOCKBACK - RECIBIR EMPUJE
# =========================================================

func recibir_empuje(
	direccion: float,
	fuerza_vertical: float = FUERZA_KNOCKBACK_VERTICAL
) -> void:

	if esta_muerto():
		return
	velocidad_knockback = _controlador_fisica.iniciar_knockback(
		direccion,
		FUERZA_KNOCKBACK_HORIZONTAL,
		fuerza_vertical
	)
	if is_zero_approx(velocidad_knockback):
		return

	if estado in [
		Estado.ATACANDO,
		Estado.ANTICIPANDO_ATAQUE
	]:
		_controlador_ataque.cancelar_por_golpe()


# =========================================================
# 65. GRAVEDAD / DAMPING - API EXTERNA
# =========================================================

func cambiar_gravedad(
	invertir: bool = true
) -> void:

	if invertir:

		gravedad_actual = -GRAVEDAD

	else:

		gravedad_actual = GRAVEDAD


func aplicar_damping(
	x: float = 0.0
) -> void:

	damping_entorno = maxf(
		x,
		0.0
	)
