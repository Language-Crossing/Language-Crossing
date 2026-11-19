extends Node2D

signal dialogue_started(context: Dictionary)
signal dialogue_choice_resolved(result: Dictionary)
signal dialogue_closed
signal object_interacted(object_id: StringName, object_name: String)
signal task_progress_changed(task: Dictionary)

const XP_PER_CORRECT_ANSWER := 10

@export_file("*.json") var config_path := ""

var level_data: Dictionary = {}
var npcs_by_id: Dictionary = {}
var tasks_by_id: Dictionary = {}
var active_npc_id: StringName = &""
var active_dialogues: Array = []
var active_dialogue_index := -1
var pending_delivery_npc_id: StringName = &""
var pending_delivery_task_ids: Array[int] = []
# Task items in the level (InteractableObject), shown or hidden as their tasks change.
var task_objects: Array[InteractableObject] = []
# True while replaying a finished conversation for practice: no checkpoint changes, no XP.
var is_replay := false
@onready var player_state: Node = get_node("/root/PlayerState")


func _ready() -> void:
	var loaded_config: Variant = ConfigHelpers.read_json(config_path, {})
	if not loaded_config is Dictionary:
		push_error("Level config must contain a JSON object: %s" % config_path)
		return

	level_data = loaded_config
	var npc_entries: Variant = level_data.get("NPCS", [])
	if not npc_entries is Array:
		push_error("Level config NPCS must be an array: %s" % config_path)
		return

	for npc_data in npc_entries:
		if not npc_data is Dictionary:
			continue
		var npc_id := StringName(str(npc_data.get("npcId", "")))
		if npc_id.is_empty():
			push_warning("Skipping an NPC with no npcId in %s" % config_path)
			continue
		npcs_by_id[npc_id] = npc_data

	var task_entries: Variant = level_data.get("TASKS", [])
	if not task_entries is Array:
		push_error("Level config TASKS must be an array: %s" % config_path)
		return
	for task_entry in task_entries:
		if not task_entry is Dictionary:
			continue
		var task_id := int(task_entry.get("taskId", 0))
		if task_id <= 0:
			push_warning("Skipping a task with no valid taskId in %s" % config_path)
			continue
		tasks_by_id[task_id] = task_entry

	_restore_unlocked_tasks()
	_connect_interactables(self)
	_refresh_task_objects(false)


func _connect_interactables(parent: Node) -> void:
	for child in parent.get_children():
		if child is InteractableNPC:
			if not npcs_by_id.has(child.npc_id):
				push_warning("NPC node '%s' has no matching config entry in %s" % [child.name, config_path])
			elif not child.interacted.is_connected(_on_npc_interacted):
				child.interacted.connect(_on_npc_interacted)
		elif child is InteractableObject and not child.interacted.is_connected(_on_object_interacted):
			child.interacted.connect(_on_object_interacted)
			task_objects.append(child)
		_connect_interactables(child)


func start_dialogue(npc_id: StringName) -> Dictionary:
	if not npcs_by_id.has(npc_id):
		push_warning("No NPC named '%s' exists in %s" % [npc_id, config_path])
		return {}

	var npc_data: Dictionary = npcs_by_id[npc_id]
	var dialogues: Variant = npc_data.get("dialogues", [])
	if not dialogues is Array or dialogues.is_empty():
		push_warning("NPC '%s' has no dialogue entries" % npc_id)
		return {}

	active_npc_id = npc_id
	var unfinished_npc_id := _find_unfinished_prerequisite(npc_id)
	if not unfinished_npc_id.is_empty():
		active_dialogues = []
		active_dialogue_index = -1
		_log_dialogue("%s is waiting on %s" % [npc_id, unfinished_npc_id])
		var waiting_context := _build_dialogue_context(npc_data, {}, false)
		waiting_context["notice"] = _build_talk_first_notice(unfinished_npc_id)
		dialogue_started.emit(waiting_context)
		return waiting_context

	active_dialogues = dialogues.duplicate(true)
	var active_task := _get_active_task_for_npc(npc_id)
	if not active_task.is_empty():
		active_dialogue_index = -1
		var task_context := _build_dialogue_context(npc_data, {}, false)
		var notice_key := "deliverNotice" if str(active_task.get("stage", "")) == "deliver" else "findNotice"
		task_context["notice"] = str(active_task.get(notice_key, active_task.get("returnNotice", "Please finish your current task first.")))
		dialogue_started.emit(task_context)
		return task_context

	var checkpoint: Dictionary = player_state.call("get_dialogue_checkpoint", int(level_data.get("levelId", 0)), str(npc_id))
	if bool(checkpoint.get("completed", false)):
		active_dialogue_index = -1
		_log_dialogue("Conversation already completed for %s" % npc_id)
		var completed_context := _build_dialogue_context(npc_data, {}, true)
		dialogue_started.emit(completed_context)
		return completed_context

	var dialogue_id := int(checkpoint.get("dialogueId", 0))
	active_dialogue_index = _find_dialogue_index(dialogue_id)
	if active_dialogue_index < 0:
		active_dialogue_index = 0
		player_state.call("set_dialogue_checkpoint",
			int(level_data.get("levelId", 0)),
			str(npc_id),
			int(active_dialogues[0].get("id", 0)),
			false
		)

	var current_dialogue: Dictionary = active_dialogues[active_dialogue_index]
	var required_task_id := int(current_dialogue.get("requiresTaskCompletion", 0))
	if required_task_id > 0 and not _is_task_completed(required_task_id):
		var task: Dictionary = tasks_by_id.get(required_task_id, {})
		active_dialogue_index = -1
		var task_context := _build_dialogue_context(npc_data, {}, false)
		task_context["notice"] = str(task.get("returnNotice", "Please finish your current task first."))
		dialogue_started.emit(task_context)
		return task_context

	var context := _build_dialogue_context(npc_data, active_dialogues[active_dialogue_index], false)
	_log_dialogue("Started %s at dialogue id %d" % [npc_id, int(context.dialogue.get("id", 0))])
	dialogue_started.emit(context)
	return context


# Restarts the finished conversation the player just agreed to repeat.
func replay_dialogue() -> Dictionary:
	if not npcs_by_id.has(active_npc_id) or active_dialogues.is_empty():
		return {}

	is_replay = true
	active_dialogue_index = 0
	_log_dialogue("Replaying completed conversation for %s" % active_npc_id)
	var context := _build_dialogue_context(npcs_by_id[active_npc_id], active_dialogues[0], false)
	dialogue_started.emit(context)
	return context


func choose_dialogue_option(option_index: int) -> Dictionary:
	if active_dialogue_index < 0 or active_dialogue_index >= active_dialogues.size():
		return {}

	var current_dialogue: Dictionary = active_dialogues[active_dialogue_index]
	var options: Variant = current_dialogue.get("options", [])
	if not options is Array or option_index < 0 or option_index >= options.size():
		return {}
	if not options[option_index] is Dictionary:
		return {}

	var selected_option: Dictionary = options[option_index]
	var is_correct := bool(selected_option.get("isAnswer", false))
	_log_dialogue(
		"%s selected option %d for dialogue id %d (correct: %s)" % [
			active_npc_id,
			option_index + 1,
			int(current_dialogue.get("id", 0)),
			is_correct
		]
	)
	var next_dialogue: Dictionary = current_dialogue
	var completed := false
	var pause_for_task := false
	if is_correct:
		var next_index := active_dialogue_index + 1
		if next_index < active_dialogues.size():
			active_dialogue_index = next_index
			next_dialogue = active_dialogues[active_dialogue_index]
		else:
			completed = true
			next_dialogue = {}
			active_dialogue_index = -1

		var target_level_id := int(level_data.get("levelId", 0))
		if not is_replay:
			_learn_dialogue_vocabulary(current_dialogue, selected_option)
			_unlock_tasks_for_dialogue(active_npc_id, int(current_dialogue.get("id", 0)))
			var pause_task_id := int(current_dialogue.get("pauseForTaskId", 0))
			pause_for_task = pause_task_id > 0 and not _is_task_completed(pause_task_id)
			var checkpoint_dialogue_id := int(current_dialogue.get("id", 0))
			if not completed:
				checkpoint_dialogue_id = int(next_dialogue.get("id", checkpoint_dialogue_id))
			if pause_for_task and completed:
				completed = false
			player_state.call(
				"set_dialogue_checkpoint",
				target_level_id,
				str(active_npc_id),
				checkpoint_dialogue_id,
				completed
			)
			if str(current_dialogue.get("kind", "")) == "quiz":
				player_state.call("add_xp", XP_PER_CORRECT_ANSWER)
			player_state.call("save_game")

	var result := {
		"npcId": str(active_npc_id),
		"response": str(selected_option.get("response", "")),
		"blankFill": str(selected_option.get("blankFill", "")),
		"isCorrect": is_correct,
		"nextDialogue": next_dialogue,
		"completed": completed,
		"pauseForTask": pause_for_task
	}
	dialogue_choice_resolved.emit(result)
	return result


func _learn_dialogue_vocabulary(dialogue: Dictionary, selected_option: Dictionary) -> void:
	var learned_term: Variant = selected_option.get("learns", {})
	if learned_term is Dictionary and not learned_term.is_empty():
		_learn_vocabulary_entry(learned_term, "dialogue for NPC '%s'" % active_npc_id)

	var taught_terms: Variant = dialogue.get("teaches", [])
	if not taught_terms is Array:
		push_error("Dialogue vocabulary must be an array for NPC '%s'" % active_npc_id)
		return

	for term in taught_terms:
		_learn_vocabulary_entry(term, "dialogue for NPC '%s'" % active_npc_id)


func _learn_vocabulary_entry(entry: Variant, source: String) -> void:
	if not entry is Dictionary:
		push_error("Vocabulary entry must be an object in %s" % source)
		return
	var spanish := str(entry.get("spanish", entry.get("spanishWord", ""))).strip_edges()
	var english := str(entry.get("english", entry.get("englishWord", ""))).strip_edges()
	if spanish.is_empty() or english.is_empty():
		push_error("Vocabulary entry is missing a Spanish or English term in %s" % source)
		return
	DictionaryManager.add_level_entry(entry)


func close_dialogue() -> void:
	_log_dialogue("Closed conversation with %s" % active_npc_id)
	active_npc_id = &""
	active_dialogues = []
	active_dialogue_index = -1
	pending_delivery_npc_id = &""
	pending_delivery_task_ids.clear()
	is_replay = false
	dialogue_closed.emit()


func _on_npc_interacted(npc_id: StringName) -> void:
	# The interact key still fires while a conversation or the dictionary is open.
	if MovementBlockers.is_blocking(get_tree()):
		return
	var pending_tasks := _get_pending_task_deliveries(npc_id)
	if not pending_tasks.is_empty():
		_show_task_delivery_dialogue(npc_id, pending_tasks)
		return

	var completed_tasks := _complete_deliverable_tasks(npc_id)
	if not completed_tasks.is_empty():
		_show_task_delivery_dialogue(npc_id, completed_tasks)
		return

	start_dialogue(npc_id)


func finish_task_delivery_dialogue() -> void:
	if pending_delivery_npc_id.is_empty():
		return

	var npc_id := pending_delivery_npc_id
	for task_id in pending_delivery_task_ids:
		var progress: Dictionary = player_state.call(
			"get_task_progress",
			int(level_data.get("levelId", 0)),
			task_id
		)
		progress["deliveryDialoguePending"] = false
		_set_task_progress(task_id, progress)

	var checkpoint: Dictionary = player_state.call(
		"get_dialogue_checkpoint",
		int(level_data.get("levelId", 0)),
		str(npc_id)
	)
	pending_delivery_npc_id = &""
	pending_delivery_task_ids.clear()
	if bool(checkpoint.get("completed", false)):
		close_dialogue()
	else:
		start_dialogue(npc_id)


func _on_object_interacted(object_id: StringName, object_name: String) -> void:
	if MovementBlockers.is_blocking(get_tree()):
		return
	print("[Interaction] You found %s." % object_name)
	_advance_find_tasks(object_id)
	object_interacted.emit(object_id, object_name)


func get_active_tasks() -> Array[Dictionary]:
	var active_tasks: Array[Dictionary] = []
	for task_id in tasks_by_id:
		var task: Dictionary = tasks_by_id[task_id]
		var progress: Dictionary = player_state.call(
			"get_task_progress",
			int(level_data.get("levelId", 0)),
			int(task_id)
		)
		if str(progress.get("status", "locked")) != "active":
			continue

		var task_view := task.duplicate(true)
		task_view["stage"] = str(progress.get("stage", "find"))
		task_view["taskDescription"] = str(task.get(
			"deliverDescription" if task_view.stage == "deliver" else "findDescription",
			task.get("taskDescription", "")
		))
		active_tasks.append(task_view)
	return active_tasks


func get_task_completion_progress() -> Dictionary:
	var completed_tasks := 0
	for task_id in tasks_by_id:
		if _is_task_completed(int(task_id)):
			completed_tasks += 1
	return {
		"completed": completed_tasks,
		"total": tasks_by_id.size()
	}


func _restore_unlocked_tasks() -> void:
	var target_level_id := int(level_data.get("levelId", 0))
	for task_id in tasks_by_id:
		var task: Dictionary = tasks_by_id[task_id]
		var progress: Dictionary = player_state.call("get_task_progress", target_level_id, int(task_id))
		if str(progress.get("status", "locked")) != "locked":
			continue

		var npc_id := StringName(str(task.get("targetNpcId", "")))
		var checkpoint: Dictionary = player_state.call(
			"get_dialogue_checkpoint",
			target_level_id,
			str(npc_id)
		)
		var task_dialogue_id := int(task.get("dialogueId", 0))
		if bool(checkpoint.get("completed", false)) or int(checkpoint.get("dialogueId", 0)) > task_dialogue_id:
			_set_task_progress(int(task_id), {"status": "active", "stage": "find"})


func _unlock_tasks_for_dialogue(npc_id: StringName, dialogue_id: int) -> void:
	for task_id in tasks_by_id:
		var task: Dictionary = tasks_by_id[task_id]
		if StringName(str(task.get("targetNpcId", ""))) != npc_id:
			continue
		if int(task.get("dialogueId", 0)) != dialogue_id:
			continue

		var progress: Dictionary = player_state.call(
			"get_task_progress",
			int(level_data.get("levelId", 0)),
			int(task_id)
		)
		if str(progress.get("status", "locked")) == "locked":
			_set_task_progress(int(task_id), {"status": "active", "stage": "find"})


func _advance_find_tasks(object_id: StringName) -> void:
	for task_id in tasks_by_id:
		var task: Dictionary = tasks_by_id[task_id]
		if StringName(str(task.get("objectId", ""))) != object_id:
			continue

		var progress: Dictionary = player_state.call(
			"get_task_progress",
			int(level_data.get("levelId", 0)),
			int(task_id)
		)
		if str(progress.get("status", "")) == "active" and str(progress.get("stage", "")) == "find":
			_set_task_progress(int(task_id), {"status": "active", "stage": "deliver"})


func _complete_deliverable_tasks(npc_id: StringName) -> Array[Dictionary]:
	var completed_tasks: Array[Dictionary] = []
	for task_id in tasks_by_id:
		var task: Dictionary = tasks_by_id[task_id]
		if StringName(str(task.get("targetNpcId", ""))) != npc_id:
			continue

		var progress: Dictionary = player_state.call(
			"get_task_progress",
			int(level_data.get("levelId", 0)),
			int(task_id)
		)
		if str(progress.get("status", "")) == "active" and str(progress.get("stage", "")) == "deliver":
			var taught_terms: Variant = task.get("teaches", [])
			if not taught_terms is Array:
				push_error("Task vocabulary must be an array for task '%s'" % task.get("taskName", task_id))
			else:
				for term in taught_terms:
					_learn_vocabulary_entry(term, "task '%s'" % task.get("taskName", task_id))
			_set_task_progress(int(task_id), {
				"status": "completed",
				"stage": "completed",
				"deliveryDialoguePending": true
			})
			var completed_task := task.duplicate(true)
			completed_task["taskId"] = int(task_id)
			completed_tasks.append(completed_task)
	return completed_tasks


func _get_active_task_for_npc(npc_id: StringName) -> Dictionary:
	for task_id in tasks_by_id:
		var task: Dictionary = tasks_by_id[task_id]
		if StringName(str(task.get("targetNpcId", ""))) != npc_id:
			continue
		var progress: Dictionary = player_state.call(
			"get_task_progress",
			int(level_data.get("levelId", 0)),
			int(task_id)
		)
		if str(progress.get("status", "")) == "active":
			var active_task := task.duplicate(true)
			active_task["stage"] = str(progress.get("stage", "find"))
			return active_task
	return {}


func _get_pending_task_deliveries(npc_id: StringName) -> Array[Dictionary]:
	var pending_tasks: Array[Dictionary] = []
	for task_id in tasks_by_id:
		var task: Dictionary = tasks_by_id[task_id]
		if StringName(str(task.get("targetNpcId", ""))) != npc_id:
			continue
		var progress: Dictionary = player_state.call(
			"get_task_progress",
			int(level_data.get("levelId", 0)),
			int(task_id)
		)
		if str(progress.get("status", "")) != "completed" or not bool(progress.get("deliveryDialoguePending", false)):
			continue
		var pending_task := task.duplicate(true)
		pending_task["taskId"] = int(task_id)
		pending_tasks.append(pending_task)
	return pending_tasks


func _advance_dialogue_checkpoint_after_delivery(task: Dictionary) -> void:
	var npc_id := StringName(str(task.get("targetNpcId", "")))
	if not npcs_by_id.has(npc_id):
		push_error("Task '%s' refers to missing NPC '%s'" % [task.get("taskName", ""), npc_id])
		return

	var dialogues: Variant = npcs_by_id[npc_id].get("dialogues", [])
	if not dialogues is Array:
		push_error("NPC '%s' dialogue data must be an array" % npc_id)
		return

	var task_dialogue_id := int(task.get("dialogueId", 0))
	var task_dialogue_index := -1
	for index in range(dialogues.size()):
		var dialogue: Variant = dialogues[index]
		if dialogue is Dictionary and int(dialogue.get("id", 0)) == task_dialogue_id:
			task_dialogue_index = index
			break
	if task_dialogue_index < 0:
		push_error("Task '%s' refers to missing dialogue id %d for NPC '%s'" % [
			task.get("taskName", ""),
			task_dialogue_id,
			npc_id
		])
		return

	var target_level_id := int(level_data.get("levelId", 0))
	var checkpoint: Dictionary = player_state.call(
		"get_dialogue_checkpoint",
		target_level_id,
		str(npc_id)
	)
	if bool(checkpoint.get("completed", false)):
		return

	var checkpoint_index := -1
	var checkpoint_dialogue_id := int(checkpoint.get("dialogueId", 0))
	for index in range(dialogues.size()):
		var dialogue: Variant = dialogues[index]
		if dialogue is Dictionary and int(dialogue.get("id", 0)) == checkpoint_dialogue_id:
			checkpoint_index = index
			break
	if checkpoint_index > task_dialogue_index:
		return

	if task_dialogue_index + 1 < dialogues.size():
		var next_dialogue: Dictionary = dialogues[task_dialogue_index + 1]
		player_state.call(
			"set_dialogue_checkpoint",
			target_level_id,
			str(npc_id),
			int(next_dialogue.get("id", 0)),
			false
		)
	else:
		player_state.call("set_dialogue_checkpoint", target_level_id, str(npc_id), task_dialogue_id, true)
	if not bool(player_state.call("save_game")):
		push_error("Could not save dialogue progress after completing task '%s'" % task.get("taskName", ""))


func _show_task_delivery_dialogue(npc_id: StringName, tasks: Array[Dictionary]) -> void:
	if not npcs_by_id.has(npc_id):
		push_error("No NPC named '%s' exists in %s" % [npc_id, config_path])
		return

	var npc_data: Dictionary = npcs_by_id[npc_id]
	var exchange: Array[Dictionary] = []
	pending_delivery_task_ids.clear()
	for task in tasks:
		_advance_dialogue_checkpoint_after_delivery(task)
		var task_id := int(task.get("taskId", 0))
		pending_delivery_task_ids.append(task_id)
		exchange.append({
			"speaker": "player",
			"text": str(task.get("returnPlayerLine", "I found the item you asked me to bring."))
		})
		exchange.append({
			"speaker": "npc",
			"text": str(task.get("returnNpcLine", "Thank you for bringing it back!"))
		})

	active_npc_id = npc_id
	active_dialogues = []
	active_dialogue_index = -1
	pending_delivery_npc_id = npc_id
	is_replay = false
	var context := _build_dialogue_context(npc_data, {}, false)
	context["exchange"] = exchange
	dialogue_started.emit(context)


func _set_task_progress(task_id: int, progress: Dictionary) -> void:
	var target_level_id := int(level_data.get("levelId", 0))
	player_state.call("set_task_progress", target_level_id, task_id, progress)
	if not bool(player_state.call("save_game")):
		push_error("Could not save task progress for task %d in level %d" % [task_id, target_level_id])

	var task: Dictionary = tasks_by_id.get(task_id, {})
	var task_update := task.duplicate(true)
	task_update["stage"] = str(progress.get("stage", ""))
	task_update["status"] = str(progress.get("status", ""))
	if task_update["status"] == "active":
		var description_key := "deliverDescription" if task_update["stage"] == "deliver" else "findDescription"
		task_update["taskDescription"] = str(task.get(description_key, task.get("taskDescription", "")))
	task_progress_changed.emit(task_update)
	_refresh_task_objects(true)
	_log_dialogue(
		"Task '%s': %s" % [
			task.get("taskName", task_id),
			task_update["status"] + (": " + task_update["stage"] if task_update["status"] == "active" else "")
		]
	)


## Tells each task item where its task is ("" before the NPC asks for it, then "find",
## "deliver", "completed") so it can show itself, hide, or ride along with the player.
## `announce` lets an item that was just picked up say "You found ...!".
func _refresh_task_objects(announce: bool) -> void:
	var level_id := int(level_data.get("levelId", 0))
	for object in task_objects:
		if not is_instance_valid(object):
			continue
		var stage := ""
		for task_id in tasks_by_id:
			if StringName(str(tasks_by_id[task_id].get("objectId", ""))) != object.object_id:
				continue
			var progress: Dictionary = player_state.call("get_task_progress", level_id, int(task_id))
			match str(progress.get("status", "locked")):
				"active":
					stage = str(progress.get("stage", "find"))
				"completed":
					stage = "completed"
		object.set_task_stage(stage, announce)


func _is_task_completed(task_id: int) -> bool:
	var progress: Dictionary = player_state.call(
		"get_task_progress",
		int(level_data.get("levelId", 0)),
		task_id
	)
	return str(progress.get("status", "")) == "completed"


func _log_dialogue(message: String) -> void:
	if OS.is_debug_build():
		print("[Dialogue] %s" % message)


# Follows the NPC's "requires" chain and returns the earliest conversation still unfinished.
func _find_unfinished_prerequisite(npc_id: StringName) -> StringName:
	var unfinished_npc_id: StringName = &""
	var required_npc_id := StringName(str(npcs_by_id[npc_id].get("requires", "")))
	for _step in range(npcs_by_id.size()):
		if not npcs_by_id.has(required_npc_id):
			break
		var checkpoint: Dictionary = player_state.call("get_dialogue_checkpoint", int(level_data.get("levelId", 0)), str(required_npc_id))
		if not bool(checkpoint.get("completed", false)):
			unfinished_npc_id = required_npc_id
		required_npc_id = StringName(str(npcs_by_id[required_npc_id].get("requires", "")))
	return unfinished_npc_id


func _build_talk_first_notice(npc_id: StringName) -> String:
	var npc_data: Dictionary = npcs_by_id[npc_id]
	return str(npc_data.get("talkFirstMessage", "Please talk to %s first!" % npc_data.get("name", npc_id)))


func _find_dialogue_index(dialogue_id: int) -> int:
	for index in range(active_dialogues.size()):
		var dialogue: Variant = active_dialogues[index]
		if dialogue is Dictionary and int(dialogue.get("id", 0)) == dialogue_id:
			return index
	return -1


func _build_dialogue_context(npc_data: Dictionary, dialogue: Dictionary, completed: bool) -> Dictionary:
	return {
		"levelId": int(level_data.get("levelId", 0)),
		"npcId": str(active_npc_id),
		"npcName": str(npc_data.get("name", active_npc_id)),
		"dialogue": dialogue.duplicate(true),
		"completed": completed
	}
