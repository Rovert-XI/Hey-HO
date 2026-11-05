extends RigidBody3D

var y_max := -INF

func _physics_process(_delta: float) -> void:
	if global_position.y > y_max + 0.01:
		y_max = global_position.y
		print("altura máxima: ", snappedf(y_max, 0.01))
