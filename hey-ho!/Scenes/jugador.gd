extends CharacterBody3D

@export var velocidad: float = 5.0
@export var gravedad: float = 9.8

@onready var animated_sprite: AnimatedSprite3D = $AnimatedSprite3D

func _physics_process(delta: float) -> void:
	# 1. Aplicar gravedad si no está en el suelo
	if not is_on_floor():
		velocity.y -= gravedad * delta
	else:
		velocity.y = 0.0

	# 2. Leer entrada de movimiento horizontal (A y D / Flechas)
	var direccion := 0.0
	if Input.is_key_pressed(KEY_D) or Input.is_action_pressed("ui_right"):
		direccion = 1.0
		animated_sprite.flip_h = false  # Mira hacia la derecha
	elif Input.is_key_pressed(KEY_A) or Input.is_action_pressed("ui_left"):
		direccion = -1.0
		animated_sprite.flip_h = true   # Mira hacia la izquierda (voltea el sprite)

	# 3. Asignar velocidad y mover
	velocity.x = direccion * velocidad
	move_and_slide()

	# 4. Cambiar entre animaciones de caminar e idle
	if abs(velocity.x) > 0.1:
		animated_sprite.play("walking")
	else:
		animated_sprite.play("idle")
