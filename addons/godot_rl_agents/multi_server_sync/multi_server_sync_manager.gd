@tool
extends Node
class_name MultiServerSyncManager

## Used for multi-policy training with SB3 (may support other libraries with a custom wrapper).
## For training a single policy or using Rllib multi-policy training, use a single Sync node instead.

## Policy names must match those set in AIControllers. Must have at least 2 policy names.
@export var policy_names: Array[String]

@export_tool_button("Create MultiServerSync Nodes") var create_nodes_button = create_nodes

@export var print_debug_info := true

var cmd_args: Dictionary
var cmd_args_port: int
var sync_nodes: Array[MultiServerSync]


func _init() -> void:
	if Engine.is_editor_hint():
		return

	cmd_args = _get_args()
	cmd_args_port = _get_cmd_arg_port()


func _ready() -> void:
	if Engine.is_editor_hint():
		return

	var parent := get_parent()
	if not parent.is_node_ready():
		await parent.ready

	sync_nodes.assign(get_children())

	var sync_nodes_size := sync_nodes.size()
	assert(
		sync_nodes_size >= 2, "Must have at least 2 sync nodes. For single policy, use Sync node."
	)

	for sync_idx in sync_nodes_size:
		if print_debug_info:
			print("Creating MultiServerSync nodes: ")
		var current_sync: MultiServerSync = sync_nodes[sync_idx]
		var port: int = _get_cmd_arg_port() + sync_idx
		current_sync.set_port(port)
		current_sync.initialize()
		if print_debug_info:
			print("Policy: " + current_sync.policy_name + " Port: " + str(port), " IDX:", sync_idx)


func create_nodes():
	print_debug_msg("Removing any existing MultiServerSync nodes")
	for node in get_children():
		node.queue_free()
		remove_child(node)

	var policy_names_size := policy_names.size()
	assert(
		policy_names_size >= 2,
		"Must have at least 2 policy names. For single policy or Rllib multi-policy training, use Sync node."
	)

	print_debug_msg("Creating MultiServerSync nodes: ")
	for policy_idx in policy_names_size:
		var new_sync := MultiServerSync.new()
		new_sync.policy_name = policy_names[policy_idx]
		new_sync.name = "Sync_%s" % new_sync.policy_name
		add_child(new_sync)
		new_sync.owner = get_tree().edited_scene_root
		print_debug_msg("Added MultiServerSync node for: " + new_sync.policy_name)


func print_debug_msg(msg: String):
	if print_debug_info:
		print(self.name, ": ", msg)


func _get_cmd_arg_port():
	return cmd_args.get("port", MultiServerSync.DEFAULT_PORT).to_int()


func _get_args() -> Dictionary:
	#print("getting command line arguments")
	var arguments = {}
	for argument in OS.get_cmdline_args():
		print(argument)
		if argument.find("=") > -1:
			var key_value = argument.split("=")
			arguments[key_value[0].lstrip("--")] = key_value[1]
		else:
			# Options without an argument will be present in the dictionary,
			# with the value set to an empty string.
			arguments[argument.lstrip("--")] = ""
	return arguments
