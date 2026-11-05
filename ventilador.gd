class_name Ventilador
extends ElementoPlayground

@export var fuerza := 19.6 # N

func realizar(cuerpo: RigidBody3D, _delta: float) -> void:
	var arriba := global_transform.basis.y.normalized()
	cuerpo.apply_central_force(arriba * fuerza)
