extends Sync
class_name MultiServerSync

## Do not add this node directly. Add a MultiServerSyncManager instead.
## This is a modified version of Sync to work with multi-server training.
## For single-policy training or multi-policy training with RLlib
## use a single Sync node instead.

## Policy name of the AI-controllers that are assigned to this sync node
@export var policy_name: String = "shared_policy"

## The port that this instance will use
var _port: int = int(DEFAULT_PORT)


## Overriden to disable automatic init of sync node
func _ready() -> void:
	return


func _physics_process(_delta):
	# two modes, human control, agent control
	# pause tree, send obs, get actions, set actions, unpause tree

	_demo_record_process()
	
	var current_action_repeat := 1 if not need_to_send_obs else action_repeat

	if n_action_steps % current_action_repeat != 0:
		n_action_steps += 1
		return

	n_action_steps += 1

	_training_process()
	_inference_process()
	_heuristic_process()


## Call to initialize sync node manually
func initialize() -> void:
	assert(not initialized, "Sync node already initialized.")
	_initialize()


func set_port(port: int) -> void:
	_port = port


func _get_port() -> int:
	return _port


func _get_agents():
	all_agents = get_tree().get_nodes_in_group("AGENT").filter(
		func(agent: AIController3D): return agent.policy_name == policy_name
	)
	assert(not all_agents.is_empty(), "No AI-controllers found with policy_name: " + policy_name)
	for agent in all_agents:
		_set_agent_mode(agent)

		if agent.control_mode == agent.ControlModes.TRAINING:
			agents_training.append(agent)
		elif agent.control_mode == agent.ControlModes.ONNX_INFERENCE:
			agents_inference.append(agent)
		elif agent.control_mode == agent.ControlModes.HUMAN:
			agents_heuristic.append(agent)
		elif agent.control_mode == agent.ControlModes.RECORD_EXPERT_DEMOS:
			assert(
				not agent_demo_record,
				"Currently only a single AIController can be used for recording expert demos."
			)
			agent_demo_record = agent

	var training_agent_count = agents_training.size()
	agents_training_policy_names.resize(training_agent_count)
	for i in range(0, training_agent_count):
		agents_training_policy_names[i] = agents_training[i].policy_name
