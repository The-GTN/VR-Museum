extends Spatial

var _arvr_interface
var _config

enum MANIPULATION_TECHNIQUE {HOMER, HOMER_CONTROLLER}
export (MANIPULATION_TECHNIQUE) var technique

onready var controller = $ARVROrigin/ARVRControllerD

var collider = null

var object = null
var parent = null
var controller_pose = null
var grabbing_node_pose = null
var controller_basis = null

var offsetTZ = 0
var offsetRY = 0

var result
var grabbing_node

func _ready():
	#Cherche l'interface OpenXR
	_arvr_interface = ARVRServer.find_interface("OpenXR")
	if _arvr_interface and _arvr_interface.initialize():
		get_viewport().arvr = true
		# Charge la configuration par defaut OpenXR
		_config = load("res://addons/godot-openxr/config/OpenXRConfig.gdns").new()
		var refresh_rate = _config.get_refresh_rate()
		if refresh_rate == 0:
			Engine.iterations_per_second = 144
		else:
			Engine.iterations_per_second = refresh_rate
		get_viewport().keep_3d_linear = _config.keep_3d_linear()
	grabbing_node = Spatial.new()
	add_child(grabbing_node)

func _physics_process(delta):
	var space_state = get_world().direct_space_state
	var from = $ARVROrigin/ARVRControllerD.global_transform.origin
	var to = from + $ARVROrigin/ARVRControllerD.global_transform.basis.xform(Vector3(0, 0, -1)) * 2000.0
	result = space_state.intersect_ray(from, to)
	
	var cursor = $ARVROrigin/ARVRControllerD/Cursor
	var joyY = $ARVROrigin/ARVRControllerD.get_joystick_axis(1)
	if joyY > 0:
		cursor.translate(Vector3(0, 0, -0.5))
	elif joyY < 0:
		cursor.translate(Vector3(0, 0, 0.5))
		
	if result :
		cursor.transform.origin = Vector3(0, 0, result.position.z + 1)
	else:
		cursor.transform.origin = Vector3(0, 0, -0.1)
	
	if grabbing_node_pose == null:
		change_material(result)

func _process(_delta):
	var difference = $ARVROrigin/ARVRControllerD.transform.origin - controller_pose
	var dist = (grabbing_node.transform.origin - $ARVROrigin/ARVRControllerD.transform.origin)
	if dist.length() < 0.5 and offsetTZ < 0:
		offsetTZ = 0
		dist = Vector3(0,0,0)
	else:
		dist = dist.normalized()
	grabbing_node.transform.origin = grabbing_node_pose + difference * 10 + dist*offsetTZ
	
	var matrix = $ARVROrigin/ARVRControllerD.transform.basis * controller_basis.inverse()
	grabbing_node.transform.basis = matrix
	
	var joyX = $ARVROrigin/ARVRControllerD.get_joystick_axis(0)
	var joyY = $ARVROrigin/ARVRControllerD.get_joystick_axis(1)
	if grabbing_node_pose != null:
		if joyX > 0.8:
			offsetRY += 5
		elif joyX < -0.8:
			offsetRY -= 5
		grabbing_node.transform.basis = grabbing_node.transform.basis.rotated(Vector3(0,1,0),deg2rad(offsetRY))
		
		if joyY > 0.8:
			offsetTZ += 0.1
		elif joyY < -0.8:
			offsetTZ -= 0.1
	
func change_material(result):
	var selected_mat = SpatialMaterial.new()
	selected_mat.albedo_color = Color(0.5, 0, 0.5)
	if result:
		if collider != result.collider:
			if collider != null:
				collider.set_material_override(null)
			collider = result.collider.get_parent()
			collider.set_material_override(selected_mat)
	else:
		if collider != null:
			collider.set_material_override(null)
			collider = null

func _on_ARVRController_button_pressed(button):
	if button == JOY_VR_TRIGGER:
		object = result.collider.get_parent()
		parent = object.get_parent()
		parent.remove_child(object)
		grabbing_node.add_child(object)
		grabbing_node.transform = Transform.IDENTITY
		grabbing_node.transform.origin = object.transform.origin
		object.transform.origin = Vector3(0, 0, 0)
		grabbing_node_pose = grabbing_node.transform.origin
		
		controller_pose = $ARVROrigin/ARVRControllerD.transform.origin
		controller_basis = $ARVROrigin/ARVRControllerD.transform.basis
		
		$ARVROrigin/ARVRControllerD/Ray.visible = false
		$ARVROrigin/ARVRControllerD/Cursor.visible = false


func _on_ARVRController_button_release(button):
	if button == JOY_VR_TRIGGER:
		object.transform = object.global_transform
		grabbing_node.remove_child(object)
		parent.add_child(object)
		parent = null
		object = null
		grabbing_node_pose = null
		
		offsetRY = 0
		offsetTZ = 0
		
		$ARVROrigin/ARVRControllerD/Ray.visible = true
		$ARVROrigin/ARVRControllerD/Cursor.visible = true
