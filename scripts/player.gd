extends Danable

# =========================================================
# SEÑALES
# =========================================================
signal jugador_murio
signal solicitado_reiniciar

# =========================================================
# CONSTANTES DE MOVIMIENTO Y FÍSICAS (Calibradas)
# =========================================================

const VELOCIDAD_AGACHADO := 120.0
const VELOCIDAD_TROTE := 240.0
const VELOCIDAD_CARRERA := 380.0
const VELOCIDAD_ESCALERA := 190.0

# Roll dive: impulso inicial y desaceleración
const VELOCIDAD_ROLL_DIVE := 360.0
const FUERZA_ROLL_DIVE := -180.0
const FRICCION_ROLL_DIVE := 650.0

const FUERZA_SALTO := -520.0
const GRAVEDAD := 1400.0

const ACELERACION_SUELO := 2400.0
const FRICCION_SUELO := 2800.0
const ACELERACION_AIRE := 1200.0

# =========================================================
# CONFIGURACIÓN VISUAL ESCALERA
# =========================================================

const ESCALA_NORMAL := Vector2(2.0, 2.0)
const ESCALA_CLIMB := Vector2(0.35, 0.35)
const OFFSET_CLIMB := Vector2.ZERO

# =========================================================
# SISTEMA DE ESTADOS
# =========================================================

enum Estado { NORMAL, ROLL_DIVE, ATAQUE, ESCALANDO, MUERTO }
var estado_actual: Estado = Estado.NORMAL

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

# Escaleras
var escalera_actual: Area2D = null
var escaleras_cercanas: Array[Area2D] = []
var direccion_escalera := 0.0

# Roll Dive
var direccion_roll := 1.0
var animacion_roll_terminada := false
var tiempo_roll := 0.0
const TIEMPO_MAX_ROLL := 0.6

# Control posterior al portal
var manteniendo_tecla_portal := false
var direccion_bloqueada_portal := 0.0

var posicion_inicial = Vector2.ZERO
var gravedad_actual = GRAVEDAD
var damping_entorno = 0.0
var reiniciador = Reiniciador.new(reiniciar)


# =========================================================
# CICLO DE VIDA
# =========================================================

func _ready() -> void:
	add_to_group("player")
	sprite.scale = ESCALA_NORMAL
	sprite.position = Vector2.ZERO
	posicion_inicial = global_position
	
	# Hace que al saltar o caer, conserve la inercia de la plataforma móvil
	platform_on_leave = PlatformOnLeave.PLATFORM_ON_LEAVE_ADD_VELOCITY
	
	if sprite.sprite_frames:
		if sprite.sprite_frames.has_animation("roll_dive"):
			sprite.sprite_frames.set_animation_loop("roll_dive", false)
		if sprite.sprite_frames.has_animation("attack"):
			sprite.sprite_frames.set_animation_loop("attack", false)

	reproducir_animacion("standing")
	sprite.animation_finished.connect(_on_animation_finished)


func _physics_process(delta: float) -> void:
	if estado_actual != Estado.ESCALANDO and not is_on_floor():
		velocity.y += gravedad_actual * delta
	
	velocity *= exp(-damping_entorno * delta)

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
		_:
			assert(
				false,
				"Estado incorrecto del jugador: %s" % Estado
					.find_key(estado_actual)
				)

	move_and_slide()


# =========================================================
# LÓGICA DE ESTADOS
# =========================================================

func _procesar_estado_normal(delta: float) -> void:
	if procesar_entrada_escalera():
		return

	var direccion := _obtener_input_horizontal()
	var agachado := Input.is_key_pressed(KEY_DOWN) or Input.is_action_pressed("ui_down")
	var corriendo := Input.is_key_pressed(KEY_Z)

	if agachado and is_on_floor() and (Input.is_action_just_pressed("ui_up") or Input.is_key_pressed(KEY_SPACE) or Input.is_key_pressed(KEY_W)):
		iniciar_roll_dive(direccion)
		return

	if Input.is_key_pressed(KEY_X) and is_on_floor():
		iniciar_ataque()
		return

	if is_on_floor() and not agachado and (Input.is_action_just_pressed("ui_up") or Input.is_key_pressed(KEY_SPACE) or Input.is_key_pressed(KEY_W)):
		velocity.y = FUERZA_SALTO

	# Control de velocidad horizontal con inercia aérea:
	if direccion != 0:
		var target_speed := 0.0
		if agachado:
			target_speed = direccion * VELOCIDAD_AGACHADO
		elif corriendo:
			target_speed = direccion * VELOCIDAD_CARRERA
		else:
			target_speed = direccion * VELOCIDAD_TROTE

		var tasa := ACELERACION_SUELO if is_on_floor() else ACELERACION_AIRE
		velocity.x = move_toward(velocity.x, target_speed, tasa * delta)
		sprite.flip_h = direccion < 0
	else:
		# Solo frena activamente si está en el suelo; en el aire conserva la inercia
		if is_on_floor():
			velocity.x = move_toward(velocity.x, 0.0, FRICCION_SUELO * delta)

	_actualizar_animacion_normal(direccion, agachado, corriendo)


func _procesar_estado_roll_dive(delta: float) -> void:
	tiempo_roll += delta
	velocity.x = move_toward(velocity.x, 0.0, FRICCION_ROLL_DIVE * delta)

	if (animacion_roll_terminada and is_on_floor()) or tiempo_roll >= TIEMPO_MAX_ROLL:
		finalizar_roll_dive()


func _procesar_estado_ataque(delta: float) -> void:
	var direccion := _obtener_input_horizontal()
	var agachado := Input.is_key_pressed(KEY_DOWN) or Input.is_action_pressed("ui_down")

	if (Input.is_action_just_pressed("ui_up") or Input.is_key_pressed(KEY_SPACE) or Input.is_key_pressed(KEY_W)) and is_on_floor():
		cambiar_estado(Estado.NORMAL)
		velocity.y = FUERZA_SALTO
		return

	if agachado or direccion != 0 or not Input.is_key_pressed(KEY_X):
		cambiar_estado(Estado.NORMAL)
		return

	velocity.x = move_toward(velocity.x, 0.0, FRICCION_SUELO * delta)


func _procesar_estado_escalando() -> void:
	if escalera_actual == null:
		finalizar_escalada()
		return

	if Input.is_key_pressed(KEY_SPACE) or Input.is_action_just_pressed("ui_up"):
		finalizar_escalada()
		velocity.y = FUERZA_SALTO
		return

	var direccion_h := _obtener_input_horizontal()
	if direccion_h != 0:
		finalizar_escalada()
		velocity.x = direccion_h * VELOCIDAD_TROTE
		sprite.flip_h = direccion_h < 0
		return

	direccion_escalera = 0.0
	if Input.is_action_pressed("ui_up") or Input.is_key_pressed(KEY_W):
		direccion_escalera = -1.0
	elif Input.is_action_pressed("ui_down") or Input.is_key_pressed(KEY_S):
		direccion_escalera = 1.0

	velocity.x = 0.0
	velocity.y = direccion_escalera * VELOCIDAD_ESCALERA

	if sprite.sprite_frames.has_animation("climb"):
		if direccion_escalera < 0:
			reproducir_animacion("climb")
		elif direccion_escalera > 0:
			reproducir_animacion("climb", true)
		else:
			sprite.pause()


func _procesar_estado_muerto() -> void:
	if Input.is_action_just_pressed("reset"):
		solicitado_reiniciar.emit()

func reiniciar() -> void:
	cambiar_estado(Estado.NORMAL)
	global_position = posicion_inicial
	reiniciar_vida()


# =========================================================
# GESTIÓN DE INPUT & PORTAL
# =========================================================

func _obtener_input_horizontal() -> float:
	var input_real := Input.get_axis("ui_left", "ui_right")
	if Input.is_key_pressed(KEY_A):
		input_real = -1.0
	elif Input.is_key_pressed(KEY_D):
		input_real = 1.0

	# Si está activo el control post-portal
	if manteniendo_tecla_portal:
		# Si se soltó la tecla o se presiona una tecla en sentido contrario
		if input_real == 0.0 or sign(input_real) != sign(direccion_bloqueada_portal):
			manteniendo_tecla_portal = false
			direccion_bloqueada_portal = 0.0
		else:
			# Invierte el input para continuar hacia donde fue expulsado
			return -direccion_bloqueada_portal

	return input_real


## Llamado exclusivamente por el portal al teletransportar
func aplicar_efecto_portal(nueva_posicion: Vector2, nueva_velocidad: Vector2) -> void:
	global_position = nueva_posicion
	velocity = nueva_velocidad

	var input_actual := Input.get_axis("ui_left", "ui_right")
	if Input.is_key_pressed(KEY_A):
		input_actual = -1.0
	elif Input.is_key_pressed(KEY_D):
		input_actual = 1.0

	if input_actual != 0.0:
		manteniendo_tecla_portal = true
		direccion_bloqueada_portal = input_actual
		# El sprite mira hacia la nueva dirección de avance (-input_actual)
		sprite.flip_h = (-input_actual) < 0
	else:
		manteniendo_tecla_portal = false
		direccion_bloqueada_portal = 0.0
		# Si entró por inercia o toque rápido, invierte la orientación actual
		sprite.flip_h = not sprite.flip_h


# =========================================================
# GESTIÓN DE ANIMACIONES Y HELPERS
# =========================================================

func _actualizar_animacion_normal(direccion: float, agachado: bool, corriendo: bool) -> void:
	if not is_on_floor():
		reproducir_animacion("jump")
	elif agachado:
		reproducir_animacion("ducking")
	elif direccion != 0:
		reproducir_animacion("run" if corriendo else "trot")
	else:
		reproducir_animacion("standing")


func reproducir_animacion(anim: String, hacia_atras: bool = false) -> void:
	if not sprite.sprite_frames.has_animation(anim):
		return

	sprite.speed_scale = 1.0
	if hacia_atras:
		if sprite.animation != anim or not sprite.is_playing():
			sprite.play_backwards(anim)
	else:
		if sprite.animation != anim or not sprite.is_playing():
			sprite.play(anim)


func cambiar_estado(nuevo_estado: Estado) -> void:
	estado_actual = nuevo_estado


# =========================================================
# ACCIONES ESPECÍFICAS
# =========================================================

func iniciar_roll_dive(direccion: float) -> void:
	cambiar_estado(Estado.ROLL_DIVE)
	animacion_roll_terminada = false
	tiempo_roll = 0.0

	if direccion != 0:
		direccion_roll = sign(direccion)
	else:
		direccion_roll = -1.0 if sprite.flip_h else 1.0

	sprite.flip_h = direccion_roll < 0
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


func iniciar_ataque() -> void:
	cambiar_estado(Estado.ATAQUE)
	velocity.x = 0.0
	reproducir_animacion("attack")
	


# =========================================================
# ESCALERAS
# =========================================================

func procesar_entrada_escalera() -> bool:
	if escaleras_cercanas.is_empty():
		return false

	var escalera := obtener_escalera()
	if escalera == null:
		return false

	var quiere_subir := Input.is_action_pressed("ui_up") or Input.is_key_pressed(KEY_W)
	var quiere_bajar := Input.is_action_pressed("ui_down") or Input.is_key_pressed(KEY_S)

	if quiere_subir and escalera.get("permitir_subir"):
		iniciar_escalada(escalera)
		return true
	elif quiere_bajar and escalera.get("permitir_bajar"):
		iniciar_escalada(escalera)
		return true

	return false


func iniciar_escalada(escalera: Area2D) -> void:
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


func obtener_escalera() -> Area2D:
	if escalera_actual != null:
		return escalera_actual
	return null if escaleras_cercanas.is_empty() else escaleras_cercanas.back()


func entrar_en_escalera(escalera: Area2D) -> void:
	if escalera != null and not escaleras_cercanas.has(escalera):
		escaleras_cercanas.append(escalera)


func salir_de_escalera(escalera: Area2D) -> void:
	if escalera == null:
		return
	escaleras_cercanas.erase(escalera)
	if escalera_actual == escalera:
		finalizar_escalada()


# =========================================================
# SEÑALES
# =========================================================

func _on_animation_finished() -> void:
	if sprite.animation == "roll_dive":
		animacion_roll_terminada = true
		if is_on_floor():
			finalizar_roll_dive()

	elif sprite.animation == "attack":
		if Input.is_key_pressed(KEY_X) and estado_actual == Estado.ATAQUE:
			sprite.play("attack")
		else:
			cambiar_estado(Estado.NORMAL)
			reproducir_animacion("standing")

# =========================================================
# INTERFAZ PÚBLICA
# =========================================================
func morir() -> void:
	cambiar_estado(Estado.MUERTO)
	reproducir_animacion("fall_on_ground")
	jugador_murio.emit()


func esta_muerto() -> bool:
	return estado_actual == Estado.MUERTO


func cambiar_gravedad(invertir: bool = true) -> void:
	gravedad_actual = -GRAVEDAD if invertir else GRAVEDAD


func aplicar_damping(x: float = 0.0) -> void:
	damping_entorno = x
