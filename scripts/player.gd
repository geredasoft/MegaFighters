extends Danable 
 
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
 
 
# ========================================================= 
# REFERENCIAS 
# ========================================================= 
 
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D 
 
@onready var hitbox_ataque: Area2D = $HitboxAtaque 
 
@onready var collision_hitbox: CollisionShape2D = ( 
	$HitboxAtaque/CollisionShape2D 
) 
 
 
# ========================================================= 
# VARIABLES - ESCALERAS 
# ========================================================= 
 
var escalera_actual: Area2D = null 
var escaleras_cercanas: Array[Area2D] = [] 
var direccion_escalera := 0.0 
 
 
# ========================================================= 
# VARIABLES - ROLL 
# ========================================================= 
 
var direccion_roll := 1.0 
var animacion_roll_terminada := false 
var tiempo_roll := 0.0 
 
 
# ========================================================= 
# VARIABLES - PORTAL 
# ========================================================= 
 
var manteniendo_tecla_portal := false 
var direccion_bloqueada_portal := 0.0 
 
 
# ========================================================= 
# VARIABLES - FÍSICA 
# ========================================================= 
 
var posicion_inicial := Vector2.ZERO 
 
var gravedad_actual := GRAVEDAD 
 
var damping_entorno := 0.0 
 
 
# ========================================================= 
# VARIABLES - COMBATE 
# ========================================================= 
 
var ataque_mantenido := false 
 
# Indica si la ventana activa del golpe está funcionando. 
var ataque_hitbox_activo := false 
 
# Enemigos golpeados durante ESTE ataque. 
# 
# Evita que el mismo enemigo reciba daño cada frame 
# mientras permanece dentro del hitbox. 
var objetivos_golpeados: Array[Node2D] = [] 
 
var velocidad_knockback: float = 0.0 
 
# ========================================================= 
# REINICIO 
# ========================================================= 
 
var reiniciador = Reiniciador.new(reiniciar) 
 
 
# ========================================================= 
# CICLO DE VIDA 
# ========================================================= 
 
func _ready() -> void: 
 
	add_to_group("Player") 
 
	posicion_inicial = global_position 
 
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
 
	if not sprite.sprite_frames: 
		return 
 
	if sprite.sprite_frames.has_animation("roll_dive"): 
		sprite.sprite_frames.set_animation_loop( 
			"roll_dive", 
			false 
		) 
 
	if sprite.sprite_frames.has_animation("attack"): 
		sprite.sprite_frames.set_animation_loop( 
			"attack", 
			false 
		) 
 
 
# ========================================================= 
# PHYSICS PROCESS 
# ========================================================= 
 
func _physics_process(delta: float) -> void: 
 
	_aplicar_gravedad(delta) 
 
	_aplicar_damping(delta) 
	 
	# --------------------------------------------- 
	# KNOCKBACK 
	# --------------------------------------------- 
 
	if absf(velocidad_knockback) > 0.1: 
 
		velocity.x = velocidad_knockback 
 
		velocidad_knockback = move_toward( 
			velocidad_knockback, 
			0.0, 
			2800.0 * delta 
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
 
	if estado_actual == Estado.ESCALANDO: 
		return 
 
	if not is_on_floor(): 
		velocity.y += gravedad_actual * delta 
 
 
func _aplicar_damping(delta: float) -> void: 
 
	if damping_entorno <= 0.0: 
		return 
 
	velocity *= exp(-damping_entorno * delta) 
 
 
# ========================================================= 
# ESTADO NORMAL 
# ========================================================= 
 
func _procesar_estado_normal(delta: float) -> void: 
 
	# Escalera tiene prioridad. 
	if procesar_entrada_escalera(): 
		return 
 
	var direccion := _obtener_input_horizontal() 
 
	var agachado := _esta_agachado() 
 
	var corriendo := _esta_corriendo() 
 
	# ----------------------------------------------------- 
	# ROLL DIVE 
	# ----------------------------------------------------- 
 
	if ( 
		agachado 
		and is_on_floor() 
		and _presiono_salto() 
	): 
		iniciar_roll_dive(direccion) 
		return 
 
	# ----------------------------------------------------- 
	# ATAQUE 
	# ----------------------------------------------------- 
 
	if _presiono_ataque() and is_on_floor(): 
		iniciar_ataque() 
		return 
 
	# ----------------------------------------------------- 
	# SALTO 
	# ----------------------------------------------------- 
 
	if ( 
		is_on_floor() 
		and not agachado 
		and _presiono_salto() 
	): 
		velocity.y = FUERZA_SALTO 
 
	# ----------------------------------------------------- 
	# MOVIMIENTO 
	# ----------------------------------------------------- 
 
	_procesar_movimiento_horizontal( 
		direccion, 
		agachado, 
		corriendo, 
		delta 
	) 
 
	# ----------------------------------------------------- 
	# ANIMACIÓN 
	# ----------------------------------------------------- 
 
	_actualizar_animacion_normal( 
		direccion, 
		agachado, 
		corriendo 
	) 
 
 
# ========================================================= 
# MOVIMIENTO HORIZONTAL 
# ========================================================= 
 
func _procesar_movimiento_horizontal( 
	direccion: float, 
	agachado: bool, 
	corriendo: bool, 
	delta: float 
) -> void: 
 
	if direccion != 0.0: 
 
		var velocidad_objetivo := VELOCIDAD_TROTE 
 
		if agachado: 
			velocidad_objetivo = VELOCIDAD_AGACHADO 
 
		elif corriendo: 
			velocidad_objetivo = VELOCIDAD_CARRERA 
 
		velocidad_objetivo *= direccion 
 
		var aceleracion := ( 
			ACELERACION_SUELO 
			if is_on_floor() 
			else ACELERACION_AIRE 
		) 
 
		velocity.x = move_toward( 
			velocity.x, 
			velocidad_objetivo, 
			aceleracion * delta 
		) 
 
		sprite.flip_h = direccion < 0.0 
		actualizar_direccion_hitbox() 
 
	else: 
 
		var friccion := ( 
			FRICCION_SUELO 
			if is_on_floor() 
			else FRICCION_AIRE 
		) 
 
		velocity.x = move_toward( 
			velocity.x, 
			0.0, 
			friccion * delta 
		) 
 
 
# ========================================================= 
# ESTADO ROLL DIVE 
# ========================================================= 
 
func _procesar_estado_roll_dive(delta: float) -> void: 
 
	tiempo_roll += delta 
 
	velocity.x = move_toward( 
		velocity.x, 
		0.0, 
		FRICCION_ROLL_DIVE * delta 
	) 
 
	if ( 
		animacion_roll_terminada 
		and is_on_floor() 
	) or tiempo_roll >= TIEMPO_MAX_ROLL: 
 
		finalizar_roll_dive() 
 
func actualizar_direccion_hitbox() -> void: 
 
	if sprite.flip_h: 
		collision_hitbox.position.x = -HITBOX_OFFSET_X 
	else: 
		collision_hitbox.position.x = HITBOX_OFFSET_X 
 
	collision_hitbox.position.y = -2.0 
 
# ========================================================= 
# ESTADO ATAQUE 
# ========================================================= 
 
func _procesar_estado_ataque(delta: float) -> void: 
 
	# ----------------------------------------------------- 
	# INPUT 
	# ----------------------------------------------------- 
 
	ataque_mantenido = _esta_atacando() 
 
	# ----------------------------------------------------- 
	# CANCELAR CON SALTO 
	# ----------------------------------------------------- 
 
	if _presiono_salto() and is_on_floor(): 
 
		terminar_ataque() 
 
		cambiar_estado(Estado.NORMAL) 
 
		velocity.y = FUERZA_SALTO 
 
		return 
 
	# ----------------------------------------------------- 
	# CANCELAR AGACHÁNDOSE 
	# ----------------------------------------------------- 
 
	if _esta_agachado(): 
 
		terminar_ataque() 
 
		cambiar_estado(Estado.NORMAL) 
 
		reproducir_animacion("ducking") 
 
		return 
 
	# ----------------------------------------------------- 
	# MOVIMIENTO DURANTE ATAQUE 
	# ----------------------------------------------------- 
 
	var direccion := _obtener_input_horizontal() 
 
	if direccion != 0.0: 
 
		velocity.x = move_toward( 
			velocity.x, 
			direccion * VELOCIDAD_ATAQUE, 
			ACELERACION_SUELO * delta 
		) 
 
		sprite.flip_h = direccion < 0.0 
		actualizar_direccion_hitbox() 
 
	else: 
 
		velocity.x = move_toward( 
			velocity.x, 
			0.0, 
			FRICCION_SUELO * delta 
		) 
 
	# ----------------------------------------------------- 
	# VENTANA DEL GOLPE 
	# ----------------------------------------------------- 
 
	_actualizar_ventana_ataque() 
 
 
# ========================================================= 
# VENTANA DEL ATAQUE 
# ========================================================= 
 
func _actualizar_ventana_ataque() -> void: 
 
	if sprite.animation != "attack": 
		desactivar_hitbox_ataque() 
		return 
 
	var frame_actual := sprite.frame 
 
	var golpe_activo := ( 
		frame_actual >= FRAME_ATAQUE_INICIO 
		and frame_actual <= FRAME_ATAQUE_FIN 
	) 
 
	# ----------------------------------------------------- 
	# DEBUG 
	# ----------------------------------------------------- 
 
	if golpe_activo != ataque_hitbox_activo: 
 
		print( 
			"ATAQUE | Frame: ", 
			frame_actual, 
			" | Hitbox: ", 
			golpe_activo 
		) 
 
	# ----------------------------------------------------- 
	# VENTANA ACTIVA 
	# ----------------------------------------------------- 
 
	if golpe_activo: 
 
		activar_hitbox_ataque() 
 
	else: 
 
		desactivar_hitbox_ataque() 
 
# ========================================================= 
# ACTIVAR HITBOX 
# ========================================================= 
 
func activar_hitbox_ataque() -> void: 
 
	if ataque_hitbox_activo: 
		return 
 
	ataque_hitbox_activo = true 
 
	hitbox_ataque.set_deferred("monitoring", true) 
	collision_hitbox.set_deferred("disabled", false) 
 
 
# ========================================================= 
# DESACTIVAR HITBOX 
# ========================================================= 
 
func desactivar_hitbox_ataque() -> void: 
 
	if not ataque_hitbox_activo: 
		return 
 
	ataque_hitbox_activo = false 
 
	hitbox_ataque.set_deferred("monitoring", false) 
	collision_hitbox.set_deferred("disabled", true) 
 
 
# ========================================================= 
# INICIAR ATAQUE 
# ========================================================= 
 
func iniciar_ataque() -> void: 
 
	if estado_actual == Estado.MUERTO: 
		return 
 
	if estado_actual == Estado.ATAQUE: 
		return 
 
	cambiar_estado(Estado.ATAQUE) 
 
	velocity.x = 0.0 
 
	ataque_mantenido = true 
 
	objetivos_golpeados.clear() 
 
	desactivar_hitbox_ataque() 
 
	sprite.frame = 0 
 
	reproducir_animacion("attack") 
 
	print("⚔️ ATAQUE INICIADO") 
 
# ========================================================= 
# TERMINAR ATAQUE 
# ========================================================= 
 
func terminar_ataque() -> void: 
 
	desactivar_hitbox_ataque() 
 
	ataque_mantenido = false 
 
	objetivos_golpeados.clear() 
 
# ========================================================= 
# ROLL DIVE 
# ========================================================= 
 
func iniciar_roll_dive(direccion: float) -> void: 
 
	cambiar_estado(Estado.ROLL_DIVE) 
 
	animacion_roll_terminada = false 
	tiempo_roll = 0.0 
 
	if direccion != 0.0: 
		direccion_roll = sign(direccion) 
	else: 
		direccion_roll = -1.0 if sprite.flip_h else 1.0 
 
	sprite.flip_h = direccion_roll < 0.0 
 
	velocity.x = direccion_roll * VELOCIDAD_ROLL_DIVE 
	velocity.y = FUERZA_ROLL_DIVE 
 
	sprite.stop() 
	sprite.play("roll_dive") 
 
 
func finalizar_roll_dive() -> void: 
 
	animacion_roll_terminada = false 
	tiempo_roll = 0.0 
 
	velocity.x = 0.0 
 
	cambiar_estado(Estado.NORMAL) 
 
	reproducir_animacion("standing") 
 
 
# ========================================================= 
# ESCALERAS 
# ========================================================= 
 
func _procesar_estado_escalando() -> void: 
 
	if escalera_actual == null: 
		finalizar_escalada() 
		return 
 
	# Saltar desde escalera. 
	if _presiono_salto(): 
 
		finalizar_escalada() 
 
		velocity.y = FUERZA_SALTO 
 
		return 
 
	# Movimiento horizontal = salir de escalera. 
	var direccion_h := _obtener_input_horizontal() 
 
	if direccion_h != 0.0: 
 
		finalizar_escalada() 
 
		velocity.x = direccion_h * VELOCIDAD_TROTE 
 
		sprite.flip_h = direccion_h < 0.0 
 
		return 
 
	# Movimiento vertical. 
	direccion_escalera = 0.0 
 
	if Input.is_action_pressed("ui_up") or Input.is_key_pressed(KEY_W): 
		direccion_escalera = -1.0 
 
	elif Input.is_action_pressed("ui_down") or Input.is_key_pressed(KEY_S): 
		direccion_escalera = 1.0 
 
	velocity.x = 0.0 
 
	velocity.y = direccion_escalera * VELOCIDAD_ESCALERA 
 
	if sprite.sprite_frames.has_animation("climb"): 
 
		if direccion_escalera < 0.0: 
 
			reproducir_animacion("climb") 
 
		elif direccion_escalera > 0.0: 
 
			reproducir_animacion("climb", true) 
 
		else: 
 
			sprite.pause() 
 
 
func iniciar_escalada(escalera: Area2D) -> void: 
 
	if escalera == null: 
		return 
 
	escalera_actual = escalera 
 
	cambiar_estado(Estado.ESCALANDO) 
 
	velocity = Vector2.ZERO 
 
	global_position.x = escalera.global_position.x 
 
	sprite.scale = ESCALA_CLIMB 
	sprite.position = OFFSET_CLIMB 
 
	if sprite.sprite_frames.has_animation("climb"): 
		reproducir_animacion("climb") 
	else: 
		reproducir_animacion("standing") 
 
 
func finalizar_escalada() -> void: 
 
	escalera_actual = null 
 
	direccion_escalera = 0.0 
 
	velocity.y = 0.0 
 
	sprite.scale = ESCALA_NORMAL 
	sprite.position = Vector2.ZERO 
 
	cambiar_estado(Estado.NORMAL) 
 
	reproducir_animacion("standing") 
 
 
func procesar_entrada_escalera() -> bool: 
 
	if escaleras_cercanas.is_empty(): 
		return false 
 
	var escalera := obtener_escalera() 
 
	if escalera == null: 
		return false 
 
	var quiere_subir := ( 
		Input.is_action_pressed("ui_up") 
		or Input.is_key_pressed(KEY_W) 
	) 
 
	var quiere_bajar := ( 
		Input.is_action_pressed("ui_down") 
		or Input.is_key_pressed(KEY_S) 
	) 
 
	if quiere_subir and escalera.get("permitir_subir"): 
		iniciar_escalada(escalera) 
		return true 
 
	if quiere_bajar and escalera.get("permitir_bajar"): 
		iniciar_escalada(escalera) 
		return true 
 
	return false 
 
 
func obtener_escalera() -> Area2D: 
 
	if escalera_actual != null: 
		return escalera_actual 
 
	if escaleras_cercanas.is_empty(): 
		return null 
 
	return escaleras_cercanas.back() 
 
 
func entrar_en_escalera(escalera: Area2D) -> void: 
 
	if ( 
		escalera != null 
		and not escaleras_cercanas.has(escalera) 
	): 
		escaleras_cercanas.append(escalera) 
 
 
func salir_de_escalera(escalera: Area2D) -> void: 
 
	if escalera == null: 
		return 
 
	escaleras_cercanas.erase(escalera) 
 
	if escalera_actual == escalera: 
		finalizar_escalada() 
 
 
# ========================================================= 
# INPUT 
# ========================================================= 
 
func _obtener_input_horizontal() -> float: 
 
	var input_real := Input.get_axis( 
		"ui_left", 
		"ui_right" 
	) 
 
	if Input.is_key_pressed(KEY_A): 
		input_real = -1.0 
 
	elif Input.is_key_pressed(KEY_D): 
		input_real = 1.0 
 
	# Control después del portal. 
	if manteniendo_tecla_portal: 
 
		if ( 
			input_real == 0.0 
			or sign(input_real) != sign(direccion_bloqueada_portal) 
		): 
 
			manteniendo_tecla_portal = false 
			direccion_bloqueada_portal = 0.0 
 
		else: 
 
			return -direccion_bloqueada_portal 
 
	return input_real 
 
 
func _presiono_salto() -> bool: 
	return ( 
		Input.is_action_just_pressed("ui_up") 
		or Input.is_key_pressed(KEY_SPACE) 
		or Input.is_key_pressed(KEY_W) 
	) 
 
 
func _presiono_ataque() -> bool: 
	return Input.is_action_just_pressed("attack") 
 
 
func _esta_atacando() -> bool: 
	return Input.is_action_pressed("attack") 
 
 
func _esta_agachado() -> bool: 
 
	return ( 
		Input.is_key_pressed(KEY_DOWN) 
		or Input.is_action_pressed("ui_down") 
	) 
 
 
func _esta_corriendo() -> bool: 
 
	return Input.is_key_pressed(KEY_Z) 
 
 
# ========================================================= 
# PORTAL 
# ========================================================= 
 
func aplicar_efecto_portal( 
	nueva_posicion: Vector2, 
	nueva_velocidad: Vector2 
) -> void: 
 
	global_position = nueva_posicion 
	velocity = nueva_velocidad 
 
	var input_actual := Input.get_axis( 
		"ui_left", 
		"ui_right" 
	) 
 
	if Input.is_key_pressed(KEY_A): 
		input_actual = -1.0 
 
	elif Input.is_key_pressed(KEY_D): 
		input_actual = 1.0 
 
	if input_actual != 0.0: 
 
		manteniendo_tecla_portal = true 
 
		direccion_bloqueada_portal = input_actual 
 
		sprite.flip_h = (-input_actual) < 0.0 
 
	else: 
 
		manteniendo_tecla_portal = false 
 
		direccion_bloqueada_portal = 0.0 
 
		sprite.flip_h = not sprite.flip_h 
 
 
# ========================================================= 
# ANIMACIONES 
# ========================================================= 
 
func reproducir_animacion( 
	anim: String, 
	hacia_atras: bool = false 
) -> void: 
 
	if not sprite.sprite_frames: 
		return 
 
	if not sprite.sprite_frames.has_animation(anim): 
		return 
 
	sprite.speed_scale = 1.0 
 
	if hacia_atras: 
 
		if ( 
			sprite.animation != anim 
			or not sprite.is_playing() 
		): 
			sprite.play_backwards(anim) 
 
	else: 
 
		if ( 
			sprite.animation != anim 
			or not sprite.is_playing() 
		): 
			sprite.play(anim) 
 
 
func _actualizar_animacion_normal( 
	direccion: float, 
	agachado: bool, 
	corriendo: bool 
) -> void: 
 
	if not is_on_floor(): 
 
		reproducir_animacion("jump") 
 
	elif agachado: 
 
		reproducir_animacion("ducking") 
 
	elif direccion != 0.0: 
 
		if corriendo: 
			reproducir_animacion("run") 
		else: 
			reproducir_animacion("trot") 
 
	else: 
 
		reproducir_animacion("standing") 
 
 
# ========================================================= 
# CAMBIO DE ESTADO 
# ========================================================= 
 
func cambiar_estado(nuevo_estado: Estado) -> void: 
 
	if estado_actual == nuevo_estado: 
		return 
 
	estado_actual = nuevo_estado 
 
 
# ========================================================= 
# FINALIZACIÓN DE ANIMACIONES 
# ========================================================= 
 
func _on_animation_finished() -> void: 
 
	match sprite.animation: 
 
		"roll_dive": 
 
			animacion_roll_terminada = true 
 
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
 
	# ----------------------------------------------------- 
	# VALIDACIONES 
	# ----------------------------------------------------- 
 
	if estado_actual != Estado.ATAQUE: 
		return 
 
	if not ataque_hitbox_activo: 
		return 
 
	if collision_hitbox.disabled: 
		return 
 
	if area == null: 
		return 
 
	# ----------------------------------------------------- 
	# SOLO HURTBOXES DE ENEMIGOS 
	# ----------------------------------------------------- 
 
	if not area.is_in_group("enemy_hurtbox"): 
		return 
 
	# ----------------------------------------------------- 
	# OBTENER ENEMIGO 
	# ----------------------------------------------------- 
 
	var enemigo := area.get_parent() 
 
	if enemigo == null: 
		return 
 
	if not enemigo.is_in_group("enemy"): 
		return 
 
	# ----------------------------------------------------- 
	# EVITAR DOBLE GOLPE 
	# ----------------------------------------------------- 
 
	if objetivos_golpeados.has(enemigo): 
		return 
 
	objetivos_golpeados.append(enemigo) 
 
	# ----------------------------------------------------- 
	# DIRECCIÓN DEL GOLPE 
	# ----------------------------------------------------- 
 
	var direccion_empuje := 1.0 
 
	if sprite.flip_h: 
		direccion_empuje = -1.0 
 
	# ----------------------------------------------------- 
	# DEBUG 
	# ----------------------------------------------------- 
 
	print("========================================") 
	print("💥 GOLPE CONECTADO") 
	print("Enemigo: ", enemigo.name) 
	print("Frame: ", sprite.frame) 
	print("Dirección: ", direccion_empuje) 
	print("========================================") 
 
	# ----------------------------------------------------- 
	# APLICAR EMPUJE 
	# ----------------------------------------------------- 
 
	if enemigo.has_method("recibir_empuje"): 
 
		enemigo.recibir_empuje( 
			direccion_empuje * FUERZA_EMPUJE_ATAQUE 
		) 
		 
func recibir_empuje( 
	direccion: float, 
	fuerza_vertical: float = FUERZA_KNOCKBACK_VERTICAL_ENEMY 
) -> void: 
 
	if estado_actual == Estado.MUERTO: 
		return 
 
	var direccion_segura := signf( 
		direccion 
	) 
 
	if is_zero_approx( 
		direccion_segura 
	): 
		return 
 
	velocidad_knockback = ( 
		direccion_segura 
		* FUERZA_KNOCKBACK_ENEMY 
	) 
 
	velocity.y = fuerza_vertical		 
 
# ========================================================= 
# MUERTE 
# ========================================================= 
 
func morir() -> void: 
 
	if estado_actual == Estado.MUERTO: 
		return 
 
	terminar_ataque() 
 
	cambiar_estado(Estado.MUERTO) 
 
	velocity = Vector2.ZERO 
 
	reproducir_animacion("fall_on_ground") 
 
	jugador_murio.emit() 
 
 
func esta_muerto() -> bool: 
 
	return estado_actual == Estado.MUERTO 
 
 
# ========================================================= 
# REINICIO 
# ========================================================= 
 
func reiniciar() -> void: 
 
	terminar_ataque() 
 
	global_position = posicion_inicial 
 
	velocity = Vector2.ZERO 
 
	cambiar_estado(Estado.NORMAL) 
 
	reiniciar_vida() 
 
	manteniendo_tecla_portal = false 
	direccion_bloqueada_portal = 0.0 
 
	reproducir_animacion("standing") 
 
 
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
