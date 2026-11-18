extends Area2D

var _dueno: Danable
var _direccion := Vector2.RIGHT
var _velocidad := 700.0
var _dano := 10
var _empuje := 80.0
var _vida_restante := 2.5
var _textura: Texture2D
var _radio := 4.0
var _escala := 1.0

@onready var _sprite: Sprite2D = $Sprite2D
@onready var _forma: CollisionShape2D = $CollisionShape2D


func configurar(
	dueno: Danable,
	posicion: Vector2,
	direccion: Vector2,
	textura: Texture2D,
	velocidad: float,
	dano: int,
	empuje: float,
	radio: float,
	escala: float
) -> void:
	_dueno = dueno
	global_position = posicion
	_direccion = direccion.normalized()
	_velocidad = velocidad
	_dano = dano
	_empuje = empuje
	_textura = textura
	_radio = radio
	_escala = escala


func _ready() -> void:
	_forma.shape = _forma.shape.duplicate()
	_sprite.texture = _textura
	_sprite.scale = Vector2.ONE * _escala
	_sprite.rotation = _direccion.angle()
	var forma_circular := _forma.shape as CircleShape2D
	if forma_circular != null:
		forma_circular.radius = _radio
	if _dueno != null and is_instance_valid(_dueno):
		collision_mask = 1 | (64 if _dueno.is_in_group("Player") else 16)
	area_entered.connect(_al_entrar_en_area)
	body_entered.connect(_al_entrar_en_cuerpo)


func _physics_process(delta: float) -> void:
	global_position += _direccion * _velocidad * delta
	_vida_restante -= delta
	if _vida_restante <= 0.0:
		queue_free()


func _al_entrar_en_area(area: Area2D) -> void:
	if _dueno == null or not is_instance_valid(_dueno):
		queue_free()
		return
	var grupo_objetivo := "enemy_hurtbox" if _dueno.is_in_group("Player") else "player_hurtbox"
	if not area.is_in_group(grupo_objetivo):
		return
	var objetivo := area.get_parent() as Danable
	if objetivo == null or not is_instance_valid(objetivo):
		return
	objetivo.recibir_dano(_dano, _dueno)
	# Las balas no deben bloquear los controles del jugador: las armas automáticas
	# pueden encadenar impactos y mantener activo el knockback continuamente.
	if not objetivo.is_in_group("Player"):
		objetivo.recibir_empuje(signf(_direccion.x), -20.0, _empuje * 0.35)
	queue_free()


func _al_entrar_en_cuerpo(cuerpo: Node2D) -> void:
	if cuerpo != _dueno:
		queue_free()
