extends RigidBody3D
class_name PrendaProyectil

# Tiempo de vida opcional para limpiar proyectiles viejos si quedan en el nivel.
@export var tiempo_vida_segundos := 12.0


func _ready() -> void:
	# Evita acumular objetos en memoria si el tiro cae lejos o fuera de vista.
	if tiempo_vida_segundos > 0.0:
		var temporizador := get_tree().create_timer(tiempo_vida_segundos)
		temporizador.timeout.connect(queue_free)


# Aplica la velocidad calculada en la trayectoria al RigidBody3D para que siga el arco.
func lanzar(velocidad_inicial: Vector3) -> void:
	linear_velocity = velocidad_inicial
