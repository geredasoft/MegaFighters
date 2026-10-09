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
 
# ========================================================= 
# SEÑALES 
# ========================================================= 
 
signal jugador_murio 
signal solicitado_reiniciar 
 
 
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

# ========================================================= 
# REFERENCIAS 
# ========================================================= 
 
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D 

@onready var _controlador_portal = PlayerPortalControllerScript.new(
	self, sprite, _controlador_entrada
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
 
 
# ========================================================= 
# PHYSICS PROCESS 
# ========================================================= 
 
func _physics_process(delta: float) -> void: 
 
	_aplicar_gravedad(delta) 
 
	_aplicar_damping(delta) 
	 
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
	_controlador_movimiento.procesar_estado_normal(delta)


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
 
		"attack": 
 
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
 
# HITBOX DE ATAQUE 
func _on_hitbox_ataque_area_entered(area: Area2D) -> void: 
	_controlador_combate.procesar_golpe(
		area,
		estado_actual == Estado.ATAQUE
	)
		 
func recibir_empuje( 
	direccion: float, 
	fuerza_vertical: float = FUERZA_KNOCKBACK_VERTICAL_ENEMY 
) -> void: 
 
	if estado_actual == Estado.MUERTO: 
		return 
	velocidad_knockback = _controlador_fisica.iniciar_knockback(
		direccion,
		FUERZA_KNOCKBACK_ENEMY,
		fuerza_vertical
	)


func _limpiar_knockback() -> void:
	velocidad_knockback = 0.0
 
# ========================================================= 
# MUERTE 
# ========================================================= 
 
func morir() -> void: 
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
