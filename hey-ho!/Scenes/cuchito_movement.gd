class_name PlayerMovement
extends CharacterBody2D

@export_category("Movimiento")
@export var velocidad: float = 300.0
@export var gravedad: float = 980.0

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

func _physics_process(delta: float) -> void:
	_aplicar_gravedad(delta)
	_procesar_movimiento_horizontal()
	move_and_slide()
	_actualizar_animaciones()

func _aplicar_gravedad(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravedad * delta
	else:
		velocity.y = 10.0 # Mantiene el contacto estable con el suelo

func _procesar_movimiento_horizontal() -> void:
	var direccion := 0.0
	
	if Input.is_key_pressed(KEY_D) or Input.is_action_pressed("ui_right"):
		direccion = 1.0
		animated_sprite.flip_h = false  # Derecha
	elif Input.is_key_pressed(KEY_A) or Input.is_action_pressed("ui_left"):
		direccion = -1.0
		animated_sprite.flip_h = true   # Izquierda

	velocity.x = direccion * velocidad

func _actualizar_animaciones() -> void:
	if abs(velocity.x) > 0.1:
		animated_sprite.play("walking")
	else:
		animated_sprite.play("idle")
