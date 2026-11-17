extends Danable 

const PlayerInputControllerScript = preload(
	"res://scripts/components/player_input_controller.gd"
)
const SpriteAnimationControllerScript = preload(
	"res://scripts/components/sprite_animation_controller.gd"
)
const PlayerLadderControllerScript = preload(
	"res://scripts/components/player_ladder_controller.gd"
)
const CombatHitProcessorScript = preload(
	"res://scripts/components/combat_hit_processor.gd"
)
const CharacterPhysicsControllerScript = preload(
	"res://scripts/components/character_physics_controller.gd"
)
const PlayerCombatControllerScript = preload(
	"res://scripts/components/player_combat_controller.gd"
)
const PlayerMovementControllerScript = preload(
	"res://scripts/components/player_movement_controller.gd"
)
const PlayerLifecycleControllerScript = preload(
	"res://scripts/components/player_lifecycle_controller.gd"
)
const PlayerPortalControllerScript = preload(
	"res://scripts/components/player_portal_controller.gd"
)
const ProjectileWeaponControllerScript = preload(
	"res://scripts/components/projectile_weapon_controller.gd"
)
const WeaponAnimationControllerScript = preload(
	"res://scripts/components/weapon_animation_controller.gd"
)
const WeaponDropControllerScript = preload(
	"res://scripts/components/weapon_drop_controller.gd"
)
const AimCursorScene: PackedScene = preload("res://scenes/aim_cursor.tscn")
 
# ========================================================= 
# SEÑALES 
# ========================================================= 
 
signal jugador_murio 
signal solicitado_reiniciar 
signal arma_recogida(textura: Texture2D, nombre: String, municion: int, capacidad: int)
signal arma_cuerpo_a_cuerpo_recogida(textura: Texture2D, nombre: String)
signal municion_cambiada(municion: int, capacidad: int)
signal arma_perdida()
 
 
# ========================================================= 
# CONSTANTES - MOVIMIENTO 
# ========================================================= 
 
const VELOCIDAD_AGACHADO := 120.0 
const VELOCIDAD_TROTE := 240.0 
const VELOCIDAD_CARRERA := 380.0 
const VELOCIDAD_ESCALERA := 190.0 
 
const ACELERACION_SUELO := 2400.0 
const ACELERACION_AIRE := 1200.0 
 
const FRICCION_SUELO := 2800.0 
const FRICCION_AIRE := 400.0 
 
 
# ========================================================= 
# CONSTANTES - SALTO 
# ========================================================= 
 
const FUERZA_SALTO := -520.0 
const GRAVEDAD := 1400.0 
 
 
# ========================================================= 
# CONSTANTES - ROLL DIVE 
# ========================================================= 
 
const VELOCIDAD_ROLL_DIVE := 360.0 
const FUERZA_ROLL_DIVE := -180.0 
const FRICCION_ROLL_DIVE := 650.0 
const TIEMPO_MAX_ROLL := 0.6 
 
 
# ========================================================= 
# CONSTANTES - ESCALERA 
# ========================================================= 
 
const ESCALA_NORMAL := Vector2(2.0, 2.0) 
const ESCALA_CLIMB := Vector2(0.35, 0.35) 
const OFFSET_CLIMB := Vector2.ZERO 
 
 
# ========================================================= 
# CONSTANTES - COMBATE 
# ========================================================= 
 
# Frame inicial donde el golpe puede hacer daño. 
const FRAME_ATAQUE_INICIO := 2 
 
# Frame final donde el golpe puede hacer daño. 
const FRAME_ATAQUE_FIN := 3 
 
# Si quieres que el jugador pueda desplazarse ligeramente 
# mientras ataca. 
const VELOCIDAD_ATAQUE := 80.0 
 
# Empuje del golpe. 
const FUERZA_EMPUJE_ATAQUE := 1.0 
const DAÑO_ATAQUE := 20
 
const HITBOX_OFFSET_X := 16.0 
 
const FUERZA_KNOCKBACK_ENEMY := 320.0 
const FUERZA_KNOCKBACK_VERTICAL_ENEMY := -180.0 
 
# ========================================================= 
# ESTADOS 
# ========================================================= 
 
enum Estado { 
	NORMAL, 
	ROLL_DIVE, 
	ATAQUE, 
	ESCALANDO, 
	MUERTO 
} 
 
var estado_actual: Estado = Estado.NORMAL 

var _controlador_entrada = PlayerInputControllerScript.new()
var _controlador_ciclo_vida
var _controlador_disparo
var _controlador_animacion_disparo
var textura_arma_recogida: Texture2D
var nombre_arma_recogida := ""
var municion_actual := 0
var municion_maxima := 0
var textura_arma_cuerpo_a_cuerpo: Texture2D
var nombre_arma_cuerpo_a_cuerpo := ""
var _modo_apuntar := false
var _disparo_pendiente_apuntado := false
var _bloquear_disparo_este_frame := false
var _cursor_apuntado: Node2D
var _direccion_apuntado := Vector2.RIGHT
var _disparo_presionado_anterior := false


func recoger_arma(textura: Texture2D, nombre: String = "Arma") -> void:
	if _es_arma_cuerpo_a_cuerpo(nombre):
		textura_arma_cuerpo_a_cuerpo = textura
		nombre_arma_cuerpo_a_cuerpo = nombre
		arma_cuerpo_a_cuerpo_recogida.emit(textura, nombre)
		return
	if textura_arma_recogida != null:
		_soltar_arma_de_fuego()
	textura_arma_recogida = textura
	nombre_arma_recogida = nombre
	municion_maxima = ProjectileWeaponControllerScript.obtener_capacidad(nombre)
	municion_actual = municion_maxima
	arma_recogida.emit(textura, nombre, municion_actual, municion_maxima)
	municion_cambiada.emit(municion_actual, municion_maxima)


func _soltar_arma_de_fuego() -> void:
	if nombre_arma_recogida.is_empty():
		return
	if _modo_apuntar:
		_salir_modo_apuntar()
	WeaponDropControllerScript.soltar(
		self,
		nombre_arma_recogida,
		-1.0 if sprite.flip_h else 1.0
	)
	textura_arma_recogida = null
	nombre_arma_recogida = ""
	municion_actual = 0
	municion_maxima = 0
	arma_perdida.emit()


func _es_arma_cuerpo_a_cuerpo(nombre: String) -> bool:
	var nombre_normalizado := nombre.to_lower()
	return nombre_normalizado in ["hacha", "sable", "machete"]

# ========================================================= 
# REFERENCIAS 
# ========================================================= 
 
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D 

@onready var _controlador_portal = PlayerPortalControllerScript.new(
	self, sprite, _controlador_entrada, Callable(self, "_limpiar_knockback")
)

@onready var _controlador_animacion = SpriteAnimationControllerScript.new(sprite)

@onready var _procesador_golpes = CombatHitProcessorScript.new()

@onready var _controlador_fisica = CharacterPhysicsControllerScript.new(self)

@onready var _controlador_escalera = PlayerLadderControllerScript.new(
	self,
	sprite,
	_controlador_entrada,
	Callable(self, "cambiar_estado"),
	Callable(self, "reproducir_animacion"),
	Estado.NORMAL,
	Estado.ESCALANDO,
	VELOCIDAD_TROTE,
	VELOCIDAD_ESCALERA,
	FUERZA_SALTO,
	ESCALA_NORMAL,
	ESCALA_CLIMB,
	OFFSET_CLIMB
)
 
@onready var hitbox_ataque: Area2D = $HitboxAtaque 
 
@onready var collision_hitbox: CollisionShape2D = ( 
	$HitboxAtaque/CollisionShape2D 
) 

@onready var _controlador_combate = PlayerCombatControllerScript.new(
	self,
	sprite,
	hitbox_ataque,
	collision_hitbox,
	_controlador_entrada,
	_procesador_golpes,
	Callable(self, "_establecer_estado_normal"),
	Callable(self, "_establecer_estado_ataque"),
	Callable(self, "reproducir_animacion"),
	{
		"frame_start": FRAME_ATAQUE_INICIO,
		"frame_end": FRAME_ATAQUE_FIN,
		"attack_speed": VELOCIDAD_ATAQUE,
		"ground_acceleration": ACELERACION_SUELO,
		"ground_friction": FRICCION_SUELO,
		"jump_force": FUERZA_SALTO,
		"damage": DAÑO_ATAQUE,
		"horizontal_knockback": FUERZA_EMPUJE_ATAQUE,
		"vertical_knockback": FUERZA_KNOCKBACK_VERTICAL_ENEMY,
		"hitbox_offset_x": HITBOX_OFFSET_X
	}
)

@onready var _controlador_movimiento = PlayerMovementControllerScript.new(
	self,
	sprite,
	_controlador_entrada,
	Callable(self, "procesar_entrada_escalera"),
	Callable(self, "iniciar_ataque"),
	Callable(self, "actualizar_direccion_hitbox"),
	Callable(self, "_actualizar_animacion_normal"),
	Callable(self, "reproducir_animacion"),
	Callable(self, "_establecer_estado_normal"),
	Callable(self, "_establecer_estado_roll"),
	{
		"velocidad_agachado": VELOCIDAD_AGACHADO,
		"velocidad_trote": VELOCIDAD_TROTE,
		"velocidad_carrera": VELOCIDAD_CARRERA,
		"aceleracion_suelo": ACELERACION_SUELO,
		"aceleracion_aire": ACELERACION_AIRE,
		"friccion_suelo": FRICCION_SUELO,
		"friccion_aire": FRICCION_AIRE,
		"fuerza_salto": FUERZA_SALTO,
		"velocidad_roll": VELOCIDAD_ROLL_DIVE,
		"fuerza_roll": FUERZA_ROLL_DIVE,
		"friccion_roll": FRICCION_ROLL_DIVE,
		"tiempo_max_roll": TIEMPO_MAX_ROLL
	}
)
 
 
# ========================================================= 
# VARIABLES - ESCALERAS 
# ========================================================= 
 
# ========================================================= 
# VARIABLES - ROLL 
# ========================================================= 
 
# ========================================================= 
# VARIABLES - PORTAL 
# ========================================================= 
 
# ========================================================= 
# VARIABLES - FÍSICA 
# ========================================================= 
 
var gravedad_actual := GRAVEDAD 
 
var damping_entorno := 0.0 
 
 
# ========================================================= 
# VARIABLES - COMBATE 
# ========================================================= 
 
var velocidad_knockback: float = 0.0 
 
# ========================================================= 
# CICLO DE VIDA 
# ========================================================= 
 
func _ready() -> void: 
 
	add_to_group("Player") 
	_controlador_disparo = ProjectileWeaponControllerScript.new(self)
	_controlador_animacion_disparo = WeaponAnimationControllerScript.new(sprite)
 
	_controlador_ciclo_vida = PlayerLifecycleControllerScript.new(
		self,
		{
			"cambiar_estado": Callable(self, "_establecer_estado_ciclo_vida"),
			"esta_muerto": Callable(self, "esta_muerto"),
			"terminar_ataque": Callable(self, "terminar_ataque"),
			"limpiar_knockback": Callable(self, "_limpiar_knockback"),
			"reproducir_animacion": Callable(self, "reproducir_animacion"),
			"reiniciar_vida": Callable(self, "reiniciar_vida"),
			"limpiar_input_portal": Callable(_controlador_entrada, "limpiar_bloqueo_portal"),
			"notificar_muerte": Callable(self, "_notificar_muerte")
		}
	)
	_controlador_ciclo_vida.establecer_posicion_inicial(global_position)
 
	sprite.scale = ESCALA_NORMAL 
	sprite.position = Vector2.ZERO 
 
	# Conserva la velocidad de plataformas móviles. 
	platform_on_leave = PlatformOnLeave.PLATFORM_ON_LEAVE_ADD_VELOCITY 
 
	# Configuración de animaciones. 
	_configurar_animaciones() 
 
	# Conectar finalización de animaciones. 
	if not sprite.animation_finished.is_connected(_on_animation_finished): 
		sprite.animation_finished.connect(_on_animation_finished) 
 
	# Conectar detección del Hitbox con Hurtboxes. 
	if not hitbox_ataque.area_entered.is_connected( 
		_on_hitbox_ataque_area_entered 
	): 
		hitbox_ataque.area_entered.connect( 
			_on_hitbox_ataque_area_entered 
		) 
 
	# Hitbox inicialmente apagado. 
	desactivar_hitbox_ataque() 
	actualizar_direccion_hitbox() 
 
	reproducir_animacion("standing") 
 
 
# ========================================================= 
# CONFIGURACIÓN DE ANIMACIONES 
# ========================================================= 
 
func _configurar_animaciones() -> void: 
	_controlador_animacion.configurar_bucle("roll_dive", false)
	_controlador_animacion.configurar_bucle("attack", false)
	# El jugador no tenía la pose de cuerpo caído que sí usa el enemigo.
	# Se crea desde su sprite de caída para que la muerte siempre sustituya
	# la pose de disparo, incluso al morir dentro del agua.
	var textura_caido := load(
		"res://assets/sprites/caido/caidoPlayerPrincipal/downed.png"
	) as Texture2D
	if textura_caido != null:
		var atlas_caido := AtlasTexture.new()
		atlas_caido.atlas = textura_caido
		atlas_caido.region = Rect2(0, 0, 19, 12)
		if sprite.sprite_frames.has_animation("fall_on_ground"):
			sprite.sprite_frames.remove_animation("fall_on_ground")
		sprite.sprite_frames.add_animation("fall_on_ground")
		sprite.sprite_frames.set_animation_speed("fall_on_ground", 5.0)
		sprite.sprite_frames.set_animation_loop("fall_on_ground", true)
		sprite.sprite_frames.add_frame("fall_on_ground", atlas_caido)
 
 
# ========================================================= 
# PHYSICS PROCESS 
# ========================================================= 
 
func _physics_process(delta: float) -> void: 
 
	_aplicar_gravedad(delta) 
 
	_aplicar_damping(delta) 
	_actualizar_apuntado()
	_procesar_disparo(delta)
	 
	# --------------------------------------------- 
	# KNOCKBACK 
	# --------------------------------------------- 
 
	if _controlador_fisica.esta_recibiendo_knockback(velocidad_knockback):
 
		velocidad_knockback = _controlador_fisica.procesar_knockback(
			velocidad_knockback,
			2800.0,
			delta
		)
 
		move_and_slide() 
 
		return 
 
	match estado_actual: 
 
		Estado.NORMAL: 
			_procesar_estado_normal(delta) 
 
		Estado.ROLL_DIVE: 
			_procesar_estado_roll_dive(delta) 
 
		Estado.ATAQUE: 
			_procesar_estado_ataque(delta) 
 
		Estado.ESCALANDO: 
			_procesar_estado_escalando() 
 
		Estado.MUERTO: 
			_procesar_estado_muerto() 
 
	move_and_slide() 


func _procesar_disparo(delta: float) -> void:
	if (
		textura_arma_recogida == null
		or municion_actual <= 0
		or estado_actual == Estado.MUERTO
		or estado_actual == Estado.ESCALANDO
	):
		return
	var direccion := _direccion_apuntado if (_modo_apuntar or _disparo_pendiente_apuntado) else Vector2(
		-1.0 if sprite.flip_h else 1.0,
		0.0
	)
	var disparo_presionado := Input.is_action_pressed("shoot") or Input.is_key_pressed(KEY_C)
	var mantener_disparo := _disparo_pendiente_apuntado or (
		disparo_presionado
		and not _modo_apuntar
		and not _bloquear_disparo_este_frame
	)
	var disparo_realizado: bool = _controlador_disparo.procesar(
		delta,
		nombre_arma_recogida,
		mantener_disparo,
		direccion
	)
	if disparo_realizado and estado_actual == Estado.NORMAL:
		_controlador_animacion_disparo.reproducir_disparo(
			nombre_arma_recogida,
			"PlayerPrincipal"
		)
	if disparo_realizado:
		_disparo_pendiente_apuntado = false
		municion_actual = maxi(municion_actual - 1, 0)
		municion_cambiada.emit(municion_actual, municion_maxima)
		if municion_actual <= 0:
			_soltar_arma_de_fuego()


func _actualizar_apuntado() -> void:
	_bloquear_disparo_este_frame = false
	if not _modo_apuntar and (textura_arma_recogida == null or municion_actual <= 0):
		_disparo_presionado_anterior = Input.is_action_pressed("shoot") or Input.is_key_pressed(KEY_C)
		return
	var disparo_presionado := Input.is_action_pressed("shoot") or Input.is_key_pressed(KEY_C)
	var paso_flecha := _obtener_flecha_pulsada()
	if not _modo_apuntar:
		# Como en Superfighters Deluxe: C + dirección entra en apuntado.
		# Se conserva C para apuntar; soltarlo confirma el disparo.
		var flecha_sostenida := _obtener_flechas_sostenidas()
		if disparo_presionado and (paso_flecha != Vector2.ZERO or flecha_sostenida != Vector2.ZERO):
			_entrar_modo_apuntar(paso_flecha if paso_flecha != Vector2.ZERO else flecha_sostenida)
			_bloquear_disparo_este_frame = true
		_disparo_presionado_anterior = disparo_presionado
		return

	if paso_flecha != Vector2.ZERO and disparo_presionado:
		_ajustar_direccion_apuntado(paso_flecha)
		_bloquear_disparo_este_frame = true
	else:
		_actualizar_posicion_cursor()

	# El disparo se confirma al soltar C, usando el ángulo final de la mira.
	if _disparo_presionado_anterior and not disparo_presionado:
		_disparo_pendiente_apuntado = true
		_salir_modo_apuntar()
	_disparo_presionado_anterior = disparo_presionado


func _obtener_flecha_pulsada() -> Vector2:
	var direccion := Vector2.ZERO
	if Input.is_action_just_pressed("ui_left"):
		direccion.x -= 1.0
	if Input.is_action_just_pressed("ui_right"):
		direccion.x += 1.0
	if Input.is_action_just_pressed("ui_up"):
		direccion.y -= 1.0
	if Input.is_action_just_pressed("ui_down"):
		direccion.y += 1.0
	return direccion


func _obtener_flechas_sostenidas() -> Vector2:
	var direccion := Vector2.ZERO
	if Input.is_action_pressed("ui_left"):
		direccion.x -= 1.0
	if Input.is_action_pressed("ui_right"):
		direccion.x += 1.0
	if Input.is_action_pressed("ui_up"):
		direccion.y -= 1.0
	if Input.is_action_pressed("ui_down"):
		direccion.y += 1.0
	return direccion


func _entrar_modo_apuntar(direccion_inicial: Vector2) -> void:
	_modo_apuntar = true
	var lado := -1.0 if sprite.flip_h else 1.0
	if not is_zero_approx(direccion_inicial.x):
		lado = signf(direccion_inicial.x)
	var inclinacion := 0.0
	if direccion_inicial.y < 0.0:
		inclinacion = -0.16
	elif direccion_inicial.y > 0.0:
		inclinacion = 0.16
	_direccion_apuntado = Vector2(lado * cos(inclinacion), sin(inclinacion))
	_cursor_apuntado = AimCursorScene.instantiate() as Node2D
	var escena := get_tree().current_scene
	if escena == null:
		_modo_apuntar = false
		return
	escena.add_child(_cursor_apuntado)
	_actualizar_posicion_cursor()
	_actualizar_orientacion_sprite(_direccion_apuntado)
	_controlador_animacion_disparo.mostrar_pose_apuntado(
		nombre_arma_recogida,
		"PlayerPrincipal"
	)


func _salir_modo_apuntar() -> void:
	_modo_apuntar = false
	if is_instance_valid(_cursor_apuntado):
		_cursor_apuntado.queue_free()
	_cursor_apuntado = null


func _ajustar_direccion_apuntado(paso: Vector2) -> void:
	var lado := -1.0 if _direccion_apuntado.x < 0.0 else 1.0
	if paso.x != 0.0:
		lado = signf(paso.x)
	var angulo := atan2(_direccion_apuntado.y, absf(_direccion_apuntado.x))
	if paso.y < 0.0:
		angulo -= 0.10
	elif paso.y > 0.0:
		angulo += 0.10
	angulo = clampf(angulo, deg_to_rad(-78.0), deg_to_rad(78.0))
	_direccion_apuntado = Vector2(lado * cos(angulo), sin(angulo)).normalized()
	_actualizar_posicion_cursor()
	_actualizar_orientacion_sprite(_direccion_apuntado)


func _actualizar_posicion_cursor() -> void:
	if not is_instance_valid(_cursor_apuntado):
		return
	var origen := global_position + Vector2(0.0, -12.0)
	_cursor_apuntado.global_position = origen + _direccion_apuntado * 150.0


func _actualizar_orientacion_sprite(direccion: Vector2) -> void:
	if absf(direccion.x) > 0.05:
		sprite.flip_h = direccion.x < 0.0
	var direccion_local := Vector2(absf(direccion.x), direccion.y).normalized()
	var angulo := direccion_local.angle()
	if sprite.flip_h:
		angulo = -angulo
	sprite.rotation = clampf(
		angulo,
		deg_to_rad(-60.0),
		deg_to_rad(60.0)
	)
 
 
# ========================================================= 
# FÍSICA 
# ========================================================= 
 
func _aplicar_gravedad(delta: float) -> void: 
	_controlador_fisica.aplicar_gravedad(
		delta,
		gravedad_actual,
		estado_actual == Estado.ESCALANDO
	)
 
 
func _aplicar_damping(delta: float) -> void: 
	_controlador_fisica.aplicar_damping(delta, damping_entorno)
 
 
# ========================================================= 
# ESTADO NORMAL 
# ========================================================= 
 
func _procesar_estado_normal(delta: float) -> void:
	if _bloquear_disparo_este_frame:
		return
	if _modo_apuntar:
		velocity.x = move_toward(velocity.x, 0.0, FRICCION_SUELO * delta)
		return
	if (
		is_on_floor()
		and textura_arma_cuerpo_a_cuerpo != null
		and Input.is_action_just_pressed("melee_attack")
	):
		_iniciar_ataque_cuerpo_a_cuerpo()
		return
	_controlador_movimiento.procesar_estado_normal(delta)


func _iniciar_ataque_cuerpo_a_cuerpo() -> void:
	if estado_actual != Estado.NORMAL:
		return
	if not _preparar_animacion_arma_cuerpo_a_cuerpo():
		return
	_controlador_animacion.configurar_bucle("melee_attack", false)
	_controlador_combate.iniciar_ataque(
		"melee_attack",
		2,
		5,
		_obtener_dano_arma_cuerpo_a_cuerpo()
	)


func _obtener_dano_arma_cuerpo_a_cuerpo() -> int:
	match nombre_arma_cuerpo_a_cuerpo.to_lower():
		"hacha":
			return 16
		"sable":
			return 12
		"machete":
			return 14
	return DAÑO_ATAQUE


func _preparar_animacion_arma_cuerpo_a_cuerpo() -> bool:
	var nombre_normalizado := nombre_arma_cuerpo_a_cuerpo.to_lower()
	if nombre_normalizado not in ["hacha", "sable", "machete"]:
		return false
	var nombre_carpeta := nombre_normalizado.capitalize()
	var nombre_animacion := "melee_attack"
	if sprite.sprite_frames.has_animation(nombre_animacion):
		sprite.sprite_frames.remove_animation(nombre_animacion)
	sprite.sprite_frames.add_animation(nombre_animacion)
	sprite.sprite_frames.set_animation_speed(nombre_animacion, 10.0)
	sprite.sprite_frames.set_animation_loop(nombre_animacion, false)
	for numero in range(1, 9):
		var ruta := "res://assets/sprites/weaponAttacks/atacar%s/atacar%sPlayerPrincipal/%s%d.png" % [
			nombre_carpeta,
			nombre_carpeta,
			nombre_normalizado,
			numero
		]
		var textura := load(ruta) as Texture2D
		if textura == null:
			push_warning("No se encontró el sprite de ataque: " + ruta)
			return false
		sprite.sprite_frames.add_frame(nombre_animacion, textura)
	return true


func _procesar_estado_roll_dive(delta: float) -> void:
	_controlador_movimiento.procesar_estado_roll_dive(delta)

func actualizar_direccion_hitbox() -> void:
	_controlador_combate.actualizar_direccion_hitbox()


func _procesar_estado_ataque(delta: float) -> void:
	_controlador_combate.procesar_estado_ataque(delta)


func activar_hitbox_ataque() -> void:
	_controlador_combate.activar_hitbox_ataque()


func desactivar_hitbox_ataque() -> void:
	_controlador_combate.desactivar_hitbox_ataque()


func iniciar_ataque() -> void:
	if estado_actual == Estado.MUERTO or estado_actual == Estado.ATAQUE:
		return
	_controlador_combate.iniciar_ataque()


func terminar_ataque() -> void:
	_controlador_combate.terminar_ataque()

func iniciar_roll_dive(direccion: float) -> void:
	_controlador_movimiento.iniciar_roll_dive(direccion)


func finalizar_roll_dive() -> void:
	_controlador_movimiento.finalizar_roll_dive()

func _procesar_estado_escalando() -> void:
	_controlador_escalera.procesar_estado_escalando(
		_obtener_input_horizontal(),
		_presiono_salto()
	)


func iniciar_escalada(escalera: Area2D) -> void:
	_controlador_escalera.iniciar_escalada(escalera)


func finalizar_escalada() -> void:
	_controlador_escalera.finalizar_escalada()


func procesar_entrada_escalera() -> bool:
	return _controlador_escalera.procesar_entrada_escalera()


func obtener_escalera() -> Area2D:
	return _controlador_escalera.obtener_escalera()


func entrar_en_escalera(escalera: Area2D) -> void:
	_controlador_escalera.entrar_en_escalera(escalera)


func salir_de_escalera(escalera: Area2D) -> void:
	_controlador_escalera.salir_de_escalera(escalera)

func _obtener_input_horizontal() -> float: 
	return _controlador_entrada.obtener_input_horizontal()
 
 
func _presiono_salto() -> bool: 
	return _controlador_entrada.presiono_salto()
 
 
func _esta_corriendo() -> bool: 
	return _controlador_entrada.esta_corriendo()
 
 
# ========================================================= 
# PORTAL 
# ========================================================= 
 
func aplicar_efecto_portal(
	nueva_posicion: Vector2,
	nueva_velocidad: Vector2
) -> void:
	_controlador_portal.aplicar_efecto(nueva_posicion, nueva_velocidad)


# =========================================================
# ANIMACIONES 
# ========================================================= 
 
func reproducir_animacion( 
	anim: String, 
	hacia_atras: bool = false 
) -> void: 
	_controlador_animacion.reproducir(anim, hacia_atras)
 
 
func _actualizar_animacion_normal( 
	direccion: float, 
	agachado: bool, 
	corriendo: bool 
) -> void: 
	if _controlador_animacion_disparo.esta_disparando():
		return
	# La inclinación solo pertenece a la pose de apuntado/disparo.
	sprite.rotation = 0.0
	_controlador_animacion.reproducir_locomocion(
		is_on_floor(), direccion, agachado, corriendo
	)
 
 
# ========================================================= 
# CAMBIO DE ESTADO 
# ========================================================= 
 
func cambiar_estado(nuevo_estado: Estado) -> void: 
 
	if estado_actual == nuevo_estado: 
		return 
 
	estado_actual = nuevo_estado 


func _establecer_estado_normal() -> void:
	cambiar_estado(Estado.NORMAL)


func _establecer_estado_ataque() -> void:
	cambiar_estado(Estado.ATAQUE)


func _establecer_estado_roll() -> void:
	cambiar_estado(Estado.ROLL_DIVE)


func _establecer_estado_ciclo_vida(nombre_estado: String) -> void:
	if nombre_estado == "muerto":
		cambiar_estado(Estado.MUERTO)
	else:
		cambiar_estado(Estado.NORMAL)
 
 
# ========================================================= 
# FINALIZACIÓN DE ANIMACIONES 
# ========================================================= 
 
func _on_animation_finished() -> void: 
 
	match sprite.animation: 
 
		"roll_dive": 
 
			_controlador_movimiento.marcar_animacion_roll_terminada()
 
			if is_on_floor(): 
				finalizar_roll_dive() 
 
		"attack", "melee_attack": 
 
			# El golpe terminó. 
			terminar_ataque() 
 
			cambiar_estado(Estado.NORMAL) 
 
			var direccion := _obtener_input_horizontal() 
 
			if direccion != 0.0: 
 
				var corriendo := _esta_corriendo() 
 
				reproducir_animacion( 
					"run" if corriendo else "trot" 
				) 
 
			else: 
 
				reproducir_animacion("standing") 

		"shoot":
			if estado_actual != Estado.MUERTO:
				_actualizar_animacion_normal(
					_obtener_input_horizontal(),
					_controlador_entrada.esta_agachado(),
					_esta_corriendo()
				)
 
# HITBOX DE ATAQUE 
func _on_hitbox_ataque_area_entered(area: Area2D) -> void: 
	_controlador_combate.procesar_golpe(
		area,
		estado_actual == Estado.ATAQUE
	)
		 
func recibir_empuje( 
	direccion: float, 
	fuerza_vertical: float = FUERZA_KNOCKBACK_VERTICAL_ENEMY,
	fuerza_horizontal: float = -1.0
) -> void: 
 
	if estado_actual == Estado.MUERTO: 
		return 
	velocidad_knockback = _controlador_fisica.iniciar_knockback(
		direccion,
		FUERZA_KNOCKBACK_ENEMY if fuerza_horizontal < 0.0 else fuerza_horizontal,
		fuerza_vertical
	)


func _limpiar_knockback() -> void:
	velocidad_knockback = 0.0
 
# ========================================================= 
# MUERTE 
# ========================================================= 
 
func morir() -> void: 
	sprite.rotation = 0.0
	_controlador_ciclo_vida.morir()


func _notificar_muerte() -> void:
	jugador_murio.emit()
 
 
func esta_muerto() -> bool: 
 
	return estado_actual == Estado.MUERTO 
 
 
# ========================================================= 
# REINICIO 
# ========================================================= 
 
func reiniciar() -> void: 
	_controlador_ciclo_vida.reiniciar()
 
 
func _procesar_estado_muerto() -> void: 
 
	if Input.is_action_just_pressed("reset"): 
 
		solicitado_reiniciar.emit() 
 
 
# ========================================================= 
# GRAVEDAD / DAMPING 
# ========================================================= 
 
func cambiar_gravedad(invertir: bool = true) -> void: 
 
	if invertir: 
		gravedad_actual = -GRAVEDAD 
	else: 
		gravedad_actual = GRAVEDAD 
 
 
func aplicar_damping(x: float = 0.0) -> void: 
 
	damping_entorno = maxf(x, 0.0)
