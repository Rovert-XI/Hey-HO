extends CharacterBody2D

@export var velocidad: float = 300.0 # Píxeles por segundo
@export var gravedad: float = 980.0

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

func _physics_process(delta: float) -> void:
	# 1. Aplicar gravedad constante
	if not is_on_floor():
		velocity.y += gravedad * delta
	else:
		# CORREGIDO: En vez de apagar en 0 bruscamente, le damos un pequeño valor 
		# positivo para asegurar que el motor siga detectando que estamos pisando el suelo.
		velocity.y = 10.0

	# 2. Leer entrada de movimiento horizontal (A y D / Flechas)
	var direccion := 0.0
	if Input.is_key_pressed(KEY_D) or Input.is_action_pressed("ui_right"):
		direccion = 1.0
		animated_sprite.flip_h = false  # Mira hacia la derecha
	elif Input.is_key_pressed(KEY_A) or Input.is_action_pressed("ui_left"):
		direccion = -1.0
		animated_sprite.flip_h = true   # Mira hacia la izquierda (voltea el sprite)

	# 3. Asignar velocidad horizontal y ejecutar físicas
	velocity.x = direccion * velocidad
	move_and_slide() # ¡La función maestra que mueve al personaje respetando colisiones!

	# 4. Cambiar entre animaciones de caminar e idle según si nos estamos moviendo
	if abs(velocity.x) > 0.1:
		animated_sprite.play("walking")
	else:
		animated_sprite.play("idle")
