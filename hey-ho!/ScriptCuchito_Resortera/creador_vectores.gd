extends Area2D #Esto permite detectar clics o toques del usuario directamente sobre el objeto de la resortera

# Señal que se emite al soltar el arrastre, enviando el vector calculado hacia otros nodos (el objeto a lanzar->camisa)
signal vector_created(vector) #Las coordenadas de la fuerza que calculó la resortera
#signar: Un nuevo tipo de evento/aviso
#Es el parámetro o dato que viaja dentro del aviso

# Longitud máxima permitida para el vector de la resortera.
@export var maximum_length := 1000

# Variables de control para el estado del arrastre y las posiciones en pantalla.
var touch_down := false
var position_start := Vector2.ZERO
var position_end := Vector2.ZERO

# Vector resultante que medirá la fuerza y dirección del lanzamiento.
var vector := Vector2.ZERO

func _ready() -> void:
	# Conexión moderna en Godot 4 de la señal input_event al método local _on_input_event.
	input_event.connect(_on_input_event)


func _draw() -> void:
	# 1. Dibujar las líneas de la resortera (como ya lo tienes)
	draw_line(
		position_start - global_position, 
		(position_end - global_position), 
		Color.BLUE, 
		8
	)
	
	draw_line(
		position_start - global_position, 
		position_start - global_position + vector, 
		Color.RED, 
		16
	)
	
	# 2. Trayectoria predicha (puntos estilo Angry Birds)
	if touch_down and vector.length() > 10:
		# Hacemos que los puntos nazcan desde el punto donde comenzó el clic (la resortera)
		var pos_inicial = position_start - global_position
		
		var vel_inicial = vector * 1.5 
		# Gravedad estándar en píxeles de Godot 2D (suele ser 980, o puedes ajustarla a tu gusto)
		var gravedad = 980.0 
		
		for i in range(1, 30):
			var t = i * 0.05 # Paso de tiempo
			var x = vel_inicial.x * t
			var y = vel_inicial.y * t + 0.5 * gravedad * t * t
			var punto_actual = pos_inicial + Vector2(x, y)
			
			# Dibuja un punto blanco formando el arco
			draw_circle(punto_actual, 4, Color.WHITE)


func _reset() -> void:
	# Limpia y reinicia los valores de posiciones y vectores tras soltar el tiro.
	position_start = Vector2.ZERO
	position_end = Vector2.ZERO
	vector = Vector2.ZERO
	
	# Godot 4: queue_redraw() reemplaza al viejo update() para refrescar los dibujos en pantalla.
	queue_redraw()
	

func _input(event) -> void:
	# Detecta cuando se suelta el botón del mouse o el toque en pantalla.
	if event.is_action_released("ui_touch"):
		touch_down = false
		emit_signal("vector_created", vector)
		_reset()
	
	# Si no se está presionando la pantalla, ignoramos el movimiento.
	if not touch_down:
		return
	
	# Mientras se arrastra el mouse/dedo, actualizamos el vector y rediseñamos la línea en tiempo real.
	if event is InputEventMouseMotion:
		position_end = event.position
		vector = -(position_end - position_start).limit_length(maximum_length)
		
		# Forzamos el redibujado inmediato para que la línea siga al cursor.
		queue_redraw()


func _on_input_event(_viewport, event, _shape_idx) -> void:
	# Detecta el clic o toque inicial dentro del área de la resortera para empezar a medir.
	if event.is_action_pressed("ui_touch"):
		touch_down = true
		position_start = event.position
