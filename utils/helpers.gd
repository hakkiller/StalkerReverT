# utils/helpers.gd
extends Node
class_name Helpers

## Жёсткая граница мира по XZ (периметр + запас на кламп камер)
const WORLD_LIMIT: float = 165.0


static func format_number(value: float, decimals: int = 0) -> String:
    var s = str(int(value))
    var result = ""
    var count = 0
    
    for i in range(s.length() - 1, -1, -1):
        if count > 0 and count % 3 == 0:
            result = " " + result
        result = s[i] + result
        count += 1
    
    if decimals > 0:
        var fractional = value - int(value)
        if fractional > 0:
            var frac_str = str(fractional).substr(1, decimals + 1)
            result += frac_str
    
    return result


static func get_random_position_in_circle(center: Vector3, min_radius: float, max_radius: float) -> Vector3:
    var angle = randf() * TAU
    var distance = min_radius + randf() * (max_radius - min_radius)
    return center + Vector3(cos(angle) * distance, 0, sin(angle) * distance)


static func get_random_position_on_ground(center: Vector3, radius: float, space_state: PhysicsDirectSpaceState3D, attempts: int = 10) -> Vector3:
    for i in range(attempts):
        var pos = center + Vector3(randf_range(-radius, radius), 100, randf_range(-radius, radius))
        
        var query = PhysicsRayQueryParameters3D.new()
        query.from = pos
        query.to = pos + Vector3(0, -200, 0)
        query.collision_mask = 1
        
        var result = space_state.intersect_ray(query)
        if result:
            return result.position + Vector3(0, 0.5, 0)
    
    return center


static func is_point_on_navmesh(point: Vector3, navigation_region: Node) -> bool:
    if not navigation_region:
        return false
    
    var map = navigation_region.get_navigation_map()
    var closest = NavigationServer3D.map_get_closest_point(map, point)
    return closest.distance_to(point) < 1.0


static func lerp_color(color1: Color, color2: Color, t: float) -> Color:
    return Color(
        lerp(color1.r, color2.r, t),
        lerp(color1.g, color2.g, t),
        lerp(color1.b, color2.b, t),
        lerp(color1.a, color2.a, t)
    )


static func get_anomaly_color(anomaly_type: GameEnums.AnomalyType) -> Color:
    match anomaly_type:
        GameEnums.AnomalyType.HEAT:
            return Color(1, 0.3, 0)
        GameEnums.AnomalyType.ELECTRIC:
            return Color(0.2, 0.6, 1)
        GameEnums.AnomalyType.ACID:
            return Color(0.6, 1, 0)
        GameEnums.AnomalyType.GRAVITY_VORTEX:
            return Color(0.5, 0, 1)
        GameEnums.AnomalyType.RADIATION_HOTSPOT:
            return Color(0.3, 1, 0.3)
        GameEnums.AnomalyType.TIME_DILATION:
            return Color(0.6, 0.3, 0.8)
        _:
            return Color.WHITE


static func get_rarity_color(rarity: GameEnums.Rarity) -> Color:
    match rarity:
        GameEnums.Rarity.COMMON:
            return Color(0.7, 0.7, 0.7)
        GameEnums.Rarity.RARE:
            return Color(0.3, 0.5, 1.0)
        GameEnums.Rarity.LEGENDARY:
            return Color(1.0, 0.8, 0.2)
        _:
            return Color.WHITE


static func safe_call(obj: Object, method: String, args: Array = [], default_return = null):
    if obj and obj.has_method(method):
        return obj.callv(method, args)
    return default_return


static func get_all_children(node: Node) -> Array:
    var children = []
    for child in node.get_children():
        children.append(child)
        children.append_array(get_all_children(child))
    return children


static func find_node_by_name(node: Node, node_name: String) -> Node:
    if node.name == node_name:
        return node
    
    for child in node.get_children():
        var result = find_node_by_name(child, node_name)
        if result:
            return result
    
    return null
