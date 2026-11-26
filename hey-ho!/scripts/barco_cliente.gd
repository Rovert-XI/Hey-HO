class_name BarcoCliente
extends Node3D

signal pedido_aceptado(barco: BarcoCliente, cantidad_prendas: int)
signal pedido_completado(barco: BarcoCliente, oro_ganado: int)
signal pedido_perdido(barco: BarcoCliente)

enum EstadoBarco {
	LLEGANDO,
	ESPERANDO_ACEPTAR,
	EN_PROCESO,
	ZARPA_FELIZ,
	ZARPA_ENOJADO
}

const COLOR_MADERA := Color("8B5A2B")
const COLOR_CREMA := Color("F6E7B0")
const COLOR_ROJO := Color("D63A3A")

@export var prendas_requeridas: int = 2
@export var tiempo_paciencia_max: float = 65.0
@export var recompensa_oro: int = 30

var numero_cliente: int = 1
var estado: EstadoBarco = EstadoBarco.LLEGANDO
var prendas_entregadas: int = 0
var paciencia_restante: float = 65.0

var _posicion_inicio: Vector3 = Vector3.ZERO
var _posicion_muelle: Vector3 = Vector3.ZERO
var _posicion_salida: Vector3 = Vector3.ZERO
var _tiempo_anim: float = 0.0

var _bandera_roja: MeshInstance3D
var _capa_burbuja: CanvasLayer
var _panel_burbuja: PanelContainer
var _boton_burbuja: Button
var _label_estado: Label
var _barra_paciencia: ProgressBar


func configurar(num: int, pos_inicio: Vector3, pos_muelle: Vector3, pos_salida: Vector3, paciencia: float = 65.0) -> void:
	numero_cliente = num
	_posicion_inicio = pos_inicio
	_posicion_muelle = pos_muelle
	_posicion_salida = pos_salida
	tiempo_paciencia_max = paciencia
	paciencia_restante = paciencia
	if is_inside_tree():
		global_position = _posicion_inicio


func _ready() -> void:
	add_to_group("barco_cliente")
	global_position = _posicion_inicio
	_construir_modelo_barco()
	_construir_burbuja_ui()


func _exit_tree() -> void:
	if is_instance_valid(_capa_burbuja):
		_capa_burbuja.queue_free()


func _process(delta: float) -> void:
	_tiempo_anim += delta

	match estado:
		EstadoBarco.LLEGANDO:
			global_position = global_position.move_toward(_posicion_muelle, 4.8 * delta)
			global_position.y = _posicion_muelle.y + sin(_tiempo_anim * 3.0) * 0.05
			if global_position.distance_to(_posicion_muelle) <= 0.08:
				global_position = _posicion_muelle
				estado = EstadoBarco.ESPERANDO_ACEPTAR
				_actualizar_ui_burbuja()

		EstadoBarco.ESPERANDO_ACEPTAR, EstadoBarco.EN_PROCESO:
			global_position.y = _posicion_muelle.y + sin(_tiempo_anim * 3.0) * 0.05
			paciencia_restante -= delta
			if paciencia_restante <= 0.0:
				paciencia_restante = 0.0
				_fallar_pedido()
			else:
				_actualizar_ui_burbuja()

		EstadoBarco.ZARPA_FELIZ, EstadoBarco.ZARPA_ENOJADO:
			global_position = global_position.move_toward(_posicion_salida, 5.5 * delta)
			if global_position.distance_to(_posicion_salida) <= 0.25:
				queue_free()

	_actualizar_posicion_burbuja_pantalla()


func aceptar_pedido() -> void:
	if estado != EstadoBarco.ESPERANDO_ACEPTAR:
		return
	estado = EstadoBarco.EN_PROCESO
	_actualizar_ui_burbuja()
	pedido_aceptado.emit(self, prendas_requeridas)


func registrar_prenda_entregada() -> bool:
	if estado != EstadoBarco.EN_PROCESO:
		return false

	prendas_entregadas += 1
	_actualizar_ui_burbuja()

	if prendas_entregadas >= prendas_requeridas:
		estado = EstadoBarco.ZARPA_FELIZ
		if is_instance_valid(_panel_burbuja):
			_panel_burbuja.visible = false
		pedido_completado.emit(self, recompensa_oro)
	return true


func esta_activo_para_entrega() -> bool:
	return estado == EstadoBarco.EN_PROCESO


func _fallar_pedido() -> void:
	estado = EstadoBarco.ZARPA_ENOJADO
	if is_instance_valid(_bandera_roja):
		_bandera_roja.visible = true
	if is_instance_valid(_panel_burbuja):
		_panel_burbuja.visible = false
	pedido_perdido.emit(self)


func _construir_modelo_barco() -> void:
	var casco := MeshInstance3D.new()
	var caja_casco := BoxMesh.new()
	caja_casco.size = Vector3(1.65, 0.52, 0.98)
	casco.mesh = caja_casco
	casco.position = Vector3(0.0, 0.22, 0.0)
	add_child(casco)
	_aplicar_color(casco, COLOR_MADERA)

	var mastil := MeshInstance3D.new()
	var cil := CylinderMesh.new()
	cil.top_radius = 0.05
	cil.bottom_radius = 0.06
	cil.height = 1.4
	mastil.mesh = cil
	mastil.position = Vector3(-0.15, 0.92, 0.0)
	add_child(mastil)
	_aplicar_color(mastil, COLOR_MADERA)

	var vela := MeshInstance3D.new()
	var caja_vela := BoxMesh.new()
	caja_vela.size = Vector3(0.08, 0.82, 0.74)
	vela.mesh = caja_vela
	vela.position = Vector3(-0.08, 1.02, 0.0)
	add_child(vela)
	_aplicar_color(vela, COLOR_CREMA)

	_bandera_roja = MeshInstance3D.new()
	var caja_bandera := BoxMesh.new()
	caja_bandera.size = Vector3(0.45, 0.28, 0.05)
	_bandera_roja.mesh = caja_bandera
	_bandera_roja.position = Vector3(-0.38, 1.52, 0.0)
	_bandera_roja.visible = false
	add_child(_bandera_roja)
	_aplicar_color(_bandera_roja, COLOR_ROJO)

	var area := Area3D.new()
	area.add_to_group("barco_cliente")
	var col := CollisionShape3D.new()
	var forma := BoxShape3D.new()
	forma.size = Vector3(1.9, 1.8, 1.3)
	col.shape = forma
	col.position = Vector3(0.0, 0.8, 0.0)
	area.add_child(col)
	area.input_event.connect(_on_area_input_event)
	add_child(area)

	var cuerpo := StaticBody3D.new()
	cuerpo.add_to_group("barco_cliente")
	var col_cuerpo := CollisionShape3D.new()
	var forma_cuerpo := BoxShape3D.new()
	forma_cuerpo.size = Vector3(1.75, 1.4, 1.15)
	col_cuerpo.shape = forma_cuerpo
	col_cuerpo.position = Vector3(0.0, 0.65, 0.0)
	cuerpo.add_child(col_cuerpo)
	add_child(cuerpo)


func _on_area_input_event(_camera: Node, event: InputEvent, _pos: Vector3, _normal: Vector3, _shape_idx: int) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			aceptar_pedido()


func _construir_burbuja_ui() -> void:
	_capa_burbuja = CanvasLayer.new()
	_capa_burbuja.layer = 15
	add_child(_capa_burbuja)

	_panel_burbuja = PanelContainer.new()
	_panel_burbuja.custom_minimum_size = Vector2(150, 62)
	_capa_burbuja.add_child(_panel_burbuja)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 3)
	_panel_burbuja.add_child(vbox)

	_boton_burbuja = Button.new()
	_boton_burbuja.text = "Barco #" + str(numero_cliente) + " (x" + str(prendas_requeridas) + ")"
	_boton_burbuja.pressed.connect(aceptar_pedido)
	vbox.add_child(_boton_burbuja)

	_label_estado = Label.new()
	_label_estado.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label_estado.text = "Clic para aceptar"
	vbox.add_child(_label_estado)

	_barra_paciencia = ProgressBar.new()
	_barra_paciencia.min_value = 0.0
	_barra_paciencia.max_value = tiempo_paciencia_max
	_barra_paciencia.value = paciencia_restante
	_barra_paciencia.show_percentage = false
	_barra_paciencia.custom_minimum_size = Vector2(138, 9)
	vbox.add_child(_barra_paciencia)

	_actualizar_ui_burbuja()


func _actualizar_ui_burbuja() -> void:
	if not is_instance_valid(_panel_burbuja):
		return

	_barra_paciencia.max_value = tiempo_paciencia_max
	_barra_paciencia.value = paciencia_restante

	if estado == EstadoBarco.ESPERANDO_ACEPTAR:
		_boton_burbuja.disabled = false
		_boton_burbuja.text = "Barco #" + str(numero_cliente) + " (" + str(prendas_requeridas) + " prendas)"
		_label_estado.text = "Clic para aceptar"
	elif estado == EstadoBarco.EN_PROCESO:
		_boton_burbuja.disabled = true
		_boton_burbuja.text = "Entregadas: " + str(prendas_entregadas) + "/" + str(prendas_requeridas)
		_label_estado.text = "Lanza secas al muelle"

	if paciencia_restante <= 12.0:
		var parpadeo: bool = int(floor(_tiempo_anim * 8.0)) % 2 == 0
		var color_alerta: Color = COLOR_ROJO if parpadeo else Color(1.0, 0.78, 0.78, 1.0)
		_panel_burbuja.modulate = color_alerta
	else:
		_panel_burbuja.modulate = Color.WHITE


func _actualizar_posicion_burbuja_pantalla() -> void:
	if not is_instance_valid(_panel_burbuja) or not _panel_burbuja.visible:
		return
	var camara := get_viewport().get_camera_3d()
	if camara == null:
		return
	var pos_mundo: Vector3 = global_position + Vector3(-0.35, 1.75, 0.0)
	if camara.is_position_behind(pos_mundo):
		_panel_burbuja.visible = false
		return
	var pos_2d: Vector2 = camara.unproject_position(pos_mundo)
	_panel_burbuja.position = pos_2d - Vector2(_panel_burbuja.size.x * 0.5, _panel_burbuja.size.y)


func _aplicar_color(malla: MeshInstance3D, color: Color) -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	malla.material_override = mat
