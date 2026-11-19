extends Node

# 1. Precargamos la escena de la resortera que ya creaste y probaste
const ESCENA_RESORTERA = preload("res://Scenes/scene_creador_vectores.tscn")

# Variable para saber si tenemos la caña/resortera equipada en este momento
var caña_equipada: Node2D = null

func _input(event: InputEvent) -> void:
	# MÉTODO A: Detectar la tecla "1" del teclado
	if event.is_action_pressed("ui_1") or (event is InputEventKey and event.pressed and event.keycode == KEY_1):
		toggle_equipar_herramienta()

# Función central para poner o quitar la herramienta
func toggle_equipar_herramienta() -> void:
	if caña_equipada == null:
		# --- EQUIPAR ---
		# Instanciamos la resortera en la memoria del juego
		caña_equipada = ESCENA_RESORTERA.instantiate()
		
		# La hacemos hija del jugador para que lo acompañe a donde se mueva
		add_child(caña_equipada)
		
		# La posicionamos frente a las manos del pirata (ajusta X e Y según prefieras)
		caña_equipada.position = Vector2(40, -10)
		
		print("¡Herramienta equipada con éxito!")
	else:
		# --- DESEQUIPAR ---
		# Eliminamos la resortera de la escena liberando memoria
		caña_equipada.queue_free()
		caña_equipada = null
		print("Herramienta guardada.")
