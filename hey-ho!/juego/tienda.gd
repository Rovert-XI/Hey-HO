extends Control
## Taller del carpintero (entre niveles): 20 oro refuerzan una soga +25 (máx. 100).
## Solo se ofrece para sogas bajo 75. Las filas se crean por código: una por cada soga (6 en total).

@onready var oro_disponible: Label = %OroDisponible
@onready var lista: VBoxContainer = %ListaSogas
@onready var boton_continuar: Button = %BotonContinuar

var _filas: Array[Dictionary] = []


func _ready() -> void:
	EstadoJuego.asegurar_carga()
	for p: String in EstadoJuego.PLATAFORMAS:
		for i in 2:
			_crear_fila(p, i)
	boton_continuar.pressed.connect(_continuar)
	_refrescar()


func _crear_fila(plataforma: String, indice: int) -> void:
	var fila := HBoxContainer.new()
	var nombre := Label.new()
	nombre.text = "%s · soga %s" % [EstadoJuego.NOMBRES_PLATAFORMA[plataforma], "AB"[indice]]
	nombre.custom_minimum_size.x = 250
	var barra := ProgressBar.new()
	barra.custom_minimum_size = Vector2(220, 18)
	barra.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	barra.show_percentage = false
	barra.max_value = EstadoJuego.SOGA_MAX
	var valor := Label.new()
	valor.custom_minimum_size.x = 60
	valor.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var boton := Button.new()
	boton.theme_type_variation = &"BotonPequeno"
	boton.text = "REFORZAR · %d" % EstadoJuego.COSTO_SOGA
	boton.pressed.connect(func() -> void:
		if EstadoJuego.comprar_soga(plataforma, indice):
			_refrescar())
	fila.add_child(nombre)
	fila.add_child(barra)
	fila.add_child(valor)
	fila.add_child(boton)
	lista.add_child(fila)
	_filas.append({"plataforma": plataforma, "indice": indice, "barra": barra, "valor": valor, "boton": boton})


func _refrescar() -> void:
	oro_disponible.text = "%d oro" % EstadoJuego.oro_total
	var primero: Button = null
	for f in _filas:
		var actual: float = EstadoJuego.sogas[f.plataforma][f.indice]
		var barra: ProgressBar = f.barra
		barra.value = actual
		barra.theme_type_variation = &"BarraRoja" if actual < 30.0 else &"BarraMadera"
		(f.valor as Label).text = str(roundi(actual))
		var boton: Button = f.boton
		var se_ofrece := actual < EstadoJuego.UMBRAL_TIENDA
		boton.disabled = not se_ofrece or EstadoJuego.oro_total < EstadoJuego.COSTO_SOGA
		boton.text = "REFORZAR · %d" % EstadoJuego.COSTO_SOGA if se_ofrece else "EN BUEN ESTADO"
		if primero == null and not boton.disabled:
			primero = boton
	(primero if primero != null else boton_continuar).grab_focus()


func _continuar() -> void:
	EstadoJuego.nivel_actual = mini(EstadoJuego.nivel_actual + 1, EstadoJuego.TOTAL_NIVELES)
	Navegador.ir_a(self, EstadoJuego.RUTA_NIVEL)
