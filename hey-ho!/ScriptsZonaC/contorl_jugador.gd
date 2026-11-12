class_name ControlJugador
extends CharacterBody3D

@export var velocidad: float = 6.0
@export var gravedad: float = 9.8

func _physics_process(delta: float) -> void:
	# 1. Aplicar gravedad si está en el aire
	if not is_on_floor():
		velocity.y -= gravedad * delta
	else:
		velocity.y = 0.0

	# 2. Leer la entrada del usuario (Teclas A/D o Flechas Izquierda/Derecha)
	var direccion := 0.0
	if Input.is_action_pressed("ui_right") or Input.is_key_pressed(KEY_D):
		direccion += 1.0
	if Input.is_action_pressed("ui_left") or Input.is_key_pressed(KEY_A):
		direccion -= 1.0

	# 3. Asignar velocidad horizontal (manteniendo Z en 0 para el plano 2.5D)
	velocity.x = direccion * velocidad
	velocity.z = 0.0

	# 4. Mover el personaje respetando colisiones y plataformas
	move_and_slide()
