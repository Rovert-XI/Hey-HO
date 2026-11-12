extends RigidBody2D

# Llamado cuando el nodo entra al árbol de escenas por primera vez.
func _ready() -> void:
	# En Godot 4, el rebote y la fricción se configuran en el Inspector 
	# usando un PhysicsMaterial, o puedes dejarlos por defecto con las propiedades del nodo.
	pass

# Función llamada desde el lanzador para aplicar la fuerza calculada por el vector.
func launch(force: Vector2) -> void:
	# Multiplicamos por -1 para invertir el tiro y le agregamos un multiplicador de potencia (ej. 1.5)
	apply_impulse(force * 1.5)
