class_name SimpleEQS extends RefCounted

var points : Array[Vector3]

var center_position: Vector3 = Vector3.ZERO

var available_points: Array[Vector3]

var nav_map

var initilized:bool = false

const num_rings: int = 3
const num_points_circle:int = 12

var angle_delta:float
var ring_angle_delta:float
var radius_delta:float

func init(inner_radius, outer_radius, map):
	radius_delta = (outer_radius - inner_radius)/(num_rings - 1)
	angle_delta = 2 * PI / num_points_circle
	nav_map = map
	generate(inner_radius)
	initilized = true

func set_center(center_pos):
	#calculate points on nav
	var delta:Vector3 = center_pos - center_position
	if delta.is_zero_approx():
		return
	center_position = center_pos
	test_points()

func generate(inner_radius):	
	var current_ring_angle:float = 0
	var ring_radius = inner_radius
	for r in range(num_rings):
		var section_angle:float = 0
		for s in range(num_points_circle):
			var pos = Vector3(ring_radius*sin(section_angle),0,ring_radius*cos(section_angle))
			points.append(pos)
			section_angle += angle_delta
		
		current_ring_angle += ring_angle_delta
		ring_radius += radius_delta
	
func test_points():
	available_points.clear()
	for point in points:
		var closest_point = NavigationServer3D.map_get_closest_point(nav_map,point)
		var delta = closest_point - point
		var is_on_nav = delta.is_zero_approx()
		if is_on_nav:
			available_points.append(point)
	
func get_point() -> Vector3:
	var point := center_position
	if available_points.size() > 0:
		var index = randi_range(0,available_points.size()-1)
		point += available_points[index]
	return point
