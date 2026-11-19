class_name pirataNivel1
extends CharacterBody3D

@export var velocidad: float = 5.0
@export var gravedad: float = 9.8
@export var eje_z_en_lugar_de_x: bool = false

@onready var visual_mesh: Node3D = $Pirata

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravedad * delta
	else:
		velocity.y = -0.1

	var dir := Input.get_axis("ui_left", "ui_right")
	if dir == 0.0:
		if Input.is_key_pressed(KEY_A):
			dir = -1.0
		elif Input.is_key_pressed(KEY_D):
			dir = 1.0

	if eje_z_en_lugar_de_x:
		velocity.z = dir * velocidad
		velocity.x = 0.0
	else:
		velocity.x = dir * velocidad
		velocity.z = 0.0

	if visual_mesh and dir != 0.0:
		visual_mesh.scale.x = abs(visual_mesh.scale.x) * sign(dir)

	move_and_slide()
