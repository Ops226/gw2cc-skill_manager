extends "res://plugins/skill_manager/resources/Condition.gd"

## Port of conditions/sm_condition_Positioning.txt.
##
## GW2Minion asked the client with `Player:IsFacingTarget`, which returned the
## quadrant directly. Here the angle between the target facing and the direction
## to the player is measured instead, the same way the rest of GW2CC does it.

const OPERATOR_LIST: Array[String] = ["In Front of", "Flanking", "Behind", "Not Facing"]

@export var operator: int = 1

func _get_uid() -> String:
	return "Positioning"

func _evaluate(_skill: Resource, context: RefCounted) -> bool:
	var target: Agent = context.attack_target
	var player: AgentChar = context.player
	if not target or not player:
		return false

	var angle: float = _angle_to_player(player, target)
	if angle < 0.0:
		return false

	match operator:
		1:
			return angle <= 45.0
		2:
			return angle > 45.0 and angle < 135.0
		3:
			return angle >= 135.0
		4:
			return angle > 45.0
	return false

## Degrees between where the target is looking and where the player stands.
static func _angle_to_player(player: AgentChar, target: Agent) -> float:
	var direction: Vector3 = player.position - target.position
	direction.y = 0.0
	if direction.length_squared() <= 0.0001:
		return -1.0
	direction = direction.normalized()

	var to_player: float = fmod(rad_to_deg(atan2(-direction.x, -direction.z)) + 360.0, 360.0)
	var facing: float = fmod(target.rotation_degrees.y + 360.0, 360.0)
	var difference: float = absf(facing - to_player)
	if difference > 180.0:
		difference = 360.0 - difference
	return difference

func _build_editor() -> Control:
	var row := new_row()
	add_label(row, "Player is ")
	add_combo(row, 150, OPERATOR_LIST, &"operator")
	add_label(row, " Target")
	return row
