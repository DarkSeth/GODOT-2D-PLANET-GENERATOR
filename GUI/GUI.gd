extends Control

@onready var viewport = $PlanetViewport
@onready var viewport_planet = $PlanetViewport/PlanetHolder
@onready var viewport_holder = $HBoxContainer/PlanetHolder
@onready var viewport_tex = $HBoxContainer/PlanetHolder/ViewportTexture
@onready var seedtext = $HBoxContainer/Settings/VBoxContainer/Seed/SeedText
@onready var optionbutton = $HBoxContainer/Settings/VBoxContainer/OptionButton
@onready var colorholder = $HBoxContainer/Settings/VBoxContainer/ColorButtonHolder
@onready var picker = $Panel/ColorPicker
@onready var random_colors = $HBoxContainer/Settings/VBoxContainer/HBoxContainer/RandomizeColors
@onready var dither_button = $HBoxContainer/Settings/VBoxContainer/HBoxContainer2/ShouldDither
@onready var layeroptions = $HBoxContainer/Settings/VBoxContainer/LayerOptions

@onready var colorbutton_scene = preload("res://GUI/ColorPickerButton.tscn")
const GIFExporter = preload("res://addons/gdgifexporter/exporter.gd")
const MedianCutQuantization = preload("res://addons/gdgifexporter/quantization/median_cut.gd")

@onready var planets = {
	"Terran Wet": preload("res://Planets/Rivers/Rivers.tscn"),
	"Terran Dry": preload("res://Planets/DryTerran/DryTerran.tscn"),	
	"Islands": preload("res://Planets/LandMasses/LandMasses.tscn"),
	"No atmosphere": preload("res://Planets/NoAtmosphere/NoAtmosphere.tscn"),
	"Gas giant 1": preload("res://Planets/GasPlanet/GasPlanet.tscn"),
	"Gas giant 2": preload("res://Planets/GasPlanetLayers/GasPlanetLayers.tscn"),
	"Ice World": preload("res://Planets/IceWorld/IceWorld.tscn"),
	"Lava World": preload("res://Planets/LavaWorld/LavaWorld.tscn"),
	"Asteroid": preload("res://Planets/Asteroids/Asteroid.tscn"),
	"Black Hole": preload("res://Planets/BlackHole/BlackHole.tscn"),
	"Galaxy": preload("res://Planets/Galaxy/Galaxy.tscn"),
	"Star": preload("res://Planets/Star/Star.tscn"),
}
var pixels = 100.0
var sd = 0
var colors = []
var should_dither = true
var chosen_type = "Terran Wet"

func _ready():
	for k in planets.keys():
		optionbutton.add_item(k)
	layeroptions.get_popup().connect("id_pressed", Callable(self, "_on_layer_selected"))
	$ImportExportPopup.connect("set_colors", Callable(self, "_on_import_colors_set"))

	_seed_random()
	_create_new_planet(planets["Terran Wet"])


func _on_OptionButton_item_selected(index):
	chosen_type = planets.keys()[index]
	var chosen_planet = planets[chosen_type]
	_create_new_planet(chosen_planet)
	_close_picker()

func _on_SliderRotation_value_changed(value):
	viewport_planet.get_child(0).set_rotates(value)

func _on_LineEdit_text_changed(new_text):
	call_deferred("_make_from_seed", int(new_text))

func _make_from_seed(new_seed):
	sd = new_seed
	seed(sd)
	viewport_planet.get_child(0).set_seed(sd)

func _create_new_planet(type):
	for c in viewport_planet.get_children():
		c.queue_free()
	
	var new_p = type.instantiate()
	viewport_planet.add_child(new_p)
	
	seed(sd)
	new_p.set_seed(sd)
	new_p.set_pixels(pixels)
	new_p.position = pixels * 0.5 * (new_p.relative_scale -1) * Vector2(1,1)
	new_p.set_dither(should_dither)
	
	colors = new_p.get_colors()
	_make_color_buttons()

	_make_layer_selection(new_p)

	await get_tree().process_frame
	viewport.size = Vector2(pixels, pixels) * new_p.relative_scale
	
	# some hardcoded values that look good in the GUI
	match new_p.gui_zoom:
		1.0:
			viewport_tex.position = Vector2(50,50)
			viewport_tex.size = Vector2(200,200)
			set_planet_holder_margin(46)
		2.0:
			viewport_tex.position = Vector2(25,25)
			viewport_tex.size = Vector2(250,250)
			set_planet_holder_margin(0)
		2.5:
			viewport_tex.position = Vector2(0,0)
			viewport_tex.size = Vector2(300,300)
			set_planet_holder_margin(0)

func set_planet_holder_margin(margin_value):
	$HBoxContainer/PlanetHolder.add_theme_constant_override("margin_top", margin_value)
	$HBoxContainer/PlanetHolder.add_theme_constant_override("margin_bottom", margin_value)
	$HBoxContainer/PlanetHolder.add_theme_constant_override("margin_left", margin_value)
	$HBoxContainer/PlanetHolder.add_theme_constant_override("margin_right", margin_value)

func _on_layer_selected(id):
	viewport_planet.get_child(0).toggle_layer(id)
	_make_layer_selection(viewport_planet.get_child(0))

func _make_layer_selection(planet):
	var layers = planet.get_layers()
	layeroptions.get_popup().clear()
	var i = 0
	for l in layers:
		layeroptions.get_popup().add_check_item(l.name)
		layeroptions.get_popup().set_item_checked(i, l.visible)
		i+=1

func _make_color_buttons():
	for b in colorholder.get_children():
		b.queue_free()
	
	for i in colors.size():
		var b = colorbutton_scene.instantiate()
		b.set_color(colors[i])
		b.set_index(i)
		b.connect("color_picked", Callable(self, "_on_colorbutton_color_picked"))
		b.connect("on_selected", Callable(self, "_on_colorbutton_pressed"))
		picker.connect("color_changed", Callable(b, "_on_picker_color_changed"))
		
		colorholder.add_child(b)

func _on_colorbutton_pressed(button):
	for b in colorholder.get_children():
		b.is_active = false
	button.is_active = true
	$Panel.visible = true
	picker.color = button.own_color

func _on_colorbutton_color_picked(color, index):
	colors[index] = color
	viewport_planet.get_child(0).set_colors(colors)

func _seed_random():
	randomize()
	sd = randi()
	seed(sd)
	seedtext.text = str(sd)
	viewport_planet.get_child(0).set_seed(sd)

func _on_Button_pressed():
	_seed_random()

func _on_ExportPNG_pressed():
	var planet = viewport_planet.get_child(0)
	var tex = viewport.get_texture().get_image()
	var image = Image.create(pixels * planet.relative_scale, pixels * planet.relative_scale, false, Image.FORMAT_RGBA8)
	var source_xy = 0
	var source_size = pixels*planet.relative_scale
	var source_rect = Rect2(source_xy, source_xy,source_size,source_size)
	image.blit_rect(tex, source_rect, Vector2(0,0))
	
	save_image(image, chosen_type + " - " + str(sd))

func export_spritesheet(sheet_size, progressbar, pixel_margin = 0.0):
	var planet = viewport_planet.get_child(0)
	progressbar.max_value = sheet_size.x * sheet_size.y
	var sheet = Image.create(pixels * sheet_size.x * planet.relative_scale + sheet_size.x*pixel_margin + pixel_margin,
				pixels * sheet_size.y * planet.relative_scale + sheet_size.y*pixel_margin + pixel_margin,
				false, Image.FORMAT_RGBA8)
	planet.override_time = true
	
	var index = 0
	for y in range(sheet_size.y):
		for x in range(sheet_size.x + 1):
			planet.set_custom_time(lerp(0.0, 1.0, (index)/float((sheet_size.x+1) * sheet_size.y)))
			await get_tree().process_frame
			
			if index != 0:
				var image = viewport.get_texture().get_image()
				var source_xy = 0
				var source_size = pixels*planet.relative_scale
				var source_rect = Rect2(source_xy, source_xy,source_size,source_size)
				var destination = Vector2(x - 1,y) * pixels * planet.relative_scale + Vector2(x * pixel_margin, (y+1) * pixel_margin)
				sheet.blit_rect(image, source_rect, destination)

			index +=1
			progressbar.value = index
	
	
	planet.override_time = false
	save_image(sheet, chosen_type + " - " + str(sd) + " - spritesheet")
	$Popup.visible = false

func save_image(img, file_name):
	if OS.has_feature('web'):
		JavaScriptBridge.download_buffer(img.save_png_to_buffer(), file_name, "image/png")
	else:
		if OS.get_name() == "OSX":
			img.save_png("user://%s.png"%file_name)
		else:
			img.save_png("res://%s.png"%file_name)

func _on_ExportSpriteSheet_pressed():
	$Panel.visible = false
	$Popup.visible = true
	$Popup.set_pixels(pixels * viewport_planet.get_child(0).relative_scale)

func _on_PickerExit_pressed():
	_close_picker()

func _close_picker():
	$Panel.visible = false
	for b in colorholder.get_children():
		b.is_active = false


func _on_RandomizeColors_pressed():
	viewport_planet.get_child(0).randomize_colors()
	colors = viewport_planet.get_child(0).get_colors()
	for i in colorholder.get_child_count():
		colorholder.get_child(i).set_color(colors[i])

func _on_ResetColors_pressed():
	viewport_planet.get_child(0).set_colors(viewport_planet.get_child(0).original_colors)
	colors = viewport_planet.get_child(0).get_colors()
	for i in colorholder.get_child_count():
		colorholder.get_child(i).set_color(colors[i])

func _on_ShouldDither_pressed():
	should_dither = !should_dither
	if should_dither:
		dither_button.text = "On"
	else:
		dither_button.text = "Off"
	viewport_planet.get_child(0).set_dither(should_dither)

func _on_ExportGIF_pressed():
	$GifPopup.visible = true
	cancel_gif = false

var cancel_gif = false
func export_gif(frames, frame_delay, progressbar):
	var planet = viewport_planet.get_child(0)
	var exporter = GIFExporter.new(pixels*planet.relative_scale, pixels*planet.relative_scale)
	progressbar.max_value = frames
	
	planet.override_time = true
	planet.set_custom_time(0.0)
	await get_tree().process_frame
	
	for i in range(frames):
		if cancel_gif:
			progressbar.value = 0
			planet.override_time = false
			break;
			return;
		
		planet.set_custom_time(lerp(0.0, 1.0, float(i)/float(frames)))

		await get_tree().process_frame
		
		var tex = viewport.get_texture().get_image()
		var image = Image.create(pixels * planet.relative_scale, pixels * planet.relative_scale, false, Image.FORMAT_RGBA8)
		
		var source_xy = 0
		var source_size = pixels*planet.relative_scale
		var source_rect = Rect2(source_xy, source_xy,source_size,source_size)
		image.blit_rect(tex, source_rect, Vector2(0,0))
		exporter.add_frame(image, frame_delay, MedianCutQuantization)
		
		progressbar.value = i
	
	if cancel_gif:
		return
	if OS.has_feature('web'):
		var data = Array(exporter.export_file_data())
		JavaScriptBridge.download_buffer(data, (chosen_type + " - " +str(sd))+".gif", "image/gif")
	else:
		var file : FileAccess
		if OS.get_name() == "OSX":
			file = FileAccess.open("user://%s.gif"%(chosen_type + " - " +str(sd)), FileAccess.WRITE)
		else:
			file = FileAccess.open("res://%s.gif"%(chosen_type + " - " +str(sd)), FileAccess.WRITE)
		file.store_buffer(exporter.export_file_data())
		file.close()

	planet.override_time = false
	$GifPopup.visible = false
	progressbar.visible = false


func _on_GifPopup_cancel_gif():
	cancel_gif = true

func _on_InputPixels_text_changed(text):
	pixels = int(text)
	pixels = clamp(pixels, 12, 5000)
	if (int(text) > 5000):
		$HBoxContainer/Settings/VBoxContainer/InputPixels.text = str(pixels)
	
	var p = viewport_planet.get_child(0)
	p.set_pixels(pixels)
	
	p.position = pixels * 0.5 * (p.relative_scale -1) * Vector2(1,1)

	await get_tree().process_frame
	viewport.size = Vector2(pixels, pixels) * p.relative_scale

func _on_ImportExportColors_pressed():
	colors = viewport_planet.get_child(0).get_colors()
	$ImportExportPopup.set_current_colors(colors)
	$ImportExportPopup.show_popup()
	
func _on_import_colors_set(i_colors):
	viewport_planet.get_child(0).set_colors(i_colors)
	for i in colorholder.get_child_count():
		colorholder.get_child(i).set_color(i_colors[i])


func _on_planet_holder_gui_input(event):
	if (event is InputEventMouseMotion || event is InputEventScreenTouch) && Input.is_action_pressed("mouse"):
		var normal = event.position / $HBoxContainer/PlanetHolder.size
		viewport_planet.get_child(0).set_light(normal)
		
		if $Panel.visible:
			_close_picker()
