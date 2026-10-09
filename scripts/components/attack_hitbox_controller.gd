extends RefCounted

var _hitbox: Area2D
var _collision_shape: CollisionShape2D


func _init(hitbox: Area2D, collision_shape: CollisionShape2D) -> void:
	_hitbox = hitbox
	_collision_shape = collision_shape


func activar() -> void:
	_hitbox.set_deferred("monitoring", true)
	_collision_shape.set_deferred("disabled", false)


func desactivar() -> void:
	_hitbox.set_deferred("monitoring", false)
	_collision_shape.set_deferred("disabled", true)
