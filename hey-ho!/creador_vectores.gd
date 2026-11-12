extends Area2D

signal vector_created(vector)

@export var max_longitud :=200

var touch_down := false
var posicion_inicial :=Vector2.ZERO
var posicion_final :=Vector2.ZERO

var vector := Vector2.ZERO

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	connect("input_event", Callable(self, "_on_input_event"))
	
	
func _draw() -> void:
	draw_line(posicion_inicial-global_position, 
	(posicion_final-global_position), 
	Color.BLUE, 8)
	
	draw_line(posicion_inicial-global_position,
	posicion_inicial-global_position+vector,
	Color.RED, 16)
	
	
func _input(event)-> void:
	
	if not touch_down:
		return
	
	if event is InputEventMouseMotion:
		posicion_final = event.position
		vector = (posicion_final - posicion_inicial).limit_length(max_longitud)
		queue_redraw()
	
func on_input_event(_viewport, event, _shape_idx) ->void:
	if event.is_action_pressed("ui_touch"):
		touch_down = true
		posicion_inicial= event.position

# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta: float) -> void:
