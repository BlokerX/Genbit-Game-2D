@tool
extends GraphEdit

var current_file_path: String = ""
var render_generation: int = 0
var _render_queued: bool = false
var _resource_to_render: QuestData = null
var file_dialog: EditorFileDialog
var _refresh_queued: bool = false
var _is_typing: bool = false
var _pending_node_positions: Dictionary = {}
var _clipboard_nodes: Array = []
var context_menu: PopupMenu
var node_context_menu: PopupMenu

func _ready() -> void:
	right_disconnects = true
	
	# --- SYGNAŁY GRAFU ---
	connection_request.connect(_on_connection_request)
	disconnection_request.connect(_on_disconnection_request)
	delete_nodes_request.connect(_on_delete_nodes_request)
	connection_to_empty.connect(_on_connection_to_empty)
	popup_request.connect(_on_popup_request)
	
	# --- SYGNAŁY KOPIOWANIA I WKLEJANIA (Ctrl-C, Ctrl-V, Ctrl-D) ---
	copy_nodes_request.connect(_on_copy_nodes_request)
	paste_nodes_request.connect(_on_paste_nodes_request)
	duplicate_nodes_request.connect(_on_duplicate_nodes_request)

	# --- MENU KONTEKSTOWE TŁA ---
	context_menu = PopupMenu.new()
	context_menu.add_item("➕ Dodaj Węzeł (Etap)", 0)
	context_menu.add_item("📋 Wklej", 1)
	context_menu.id_pressed.connect(_on_context_menu_pressed)
	add_child(context_menu)

	# --- MENU KONTEKSTOWE WĘZŁA ---
	node_context_menu = PopupMenu.new()
	node_context_menu.add_item("📄 Kopiuj", 0)
	node_context_menu.add_item("📑 Duplikuj", 1)
	node_context_menu.id_pressed.connect(_on_node_context_menu_pressed)
	add_child(node_context_menu)

	# --- GÓRNY PASEK NARZĘDZI ---
	var toolbar = get_menu_hbox()
	
	var load_btn = Button.new()
	load_btn.text = "📂 Wczytaj Graf"
	load_btn.pressed.connect(_on_load_pressed)
	toolbar.add_child(load_btn)
	toolbar.move_child(load_btn, 0)
	
	var refresh_btn = Button.new()
	refresh_btn.text = "🔄 Odśwież Graf"
	refresh_btn.pressed.connect(_on_refresh_pressed)
	toolbar.add_child(refresh_btn)
	toolbar.move_child(refresh_btn, 1)
	
	var edit_graph_btn = Button.new()
	edit_graph_btn.text = "⚙️ Właściwości Grafu"
	edit_graph_btn.pressed.connect(_on_edit_graph_pressed)
	toolbar.add_child(edit_graph_btn)
	toolbar.move_child(edit_graph_btn, 2)
	
	var save_btn = Button.new()
	save_btn.text = "💾 Zapisz Układ"
	save_btn.pressed.connect(_save_layout)
	toolbar.add_child(save_btn)
	toolbar.move_child(save_btn, 3)
	
	var arrange_btn = Button.new()
	arrange_btn.text = "✨ Auto-Rozmieść"
	arrange_btn.pressed.connect(_smart_arrange_nodes)
	toolbar.add_child(arrange_btn)
	toolbar.move_child(arrange_btn, 4)

	var sep = VSeparator.new()
	toolbar.add_child(sep)
	toolbar.move_child(sep, 5)
	
	var info_lbl = Label.new()
	info_lbl.text = " Tryb Edycji Zadań (Skróty: Ctrl+C, Ctrl+V, Ctrl+D) "
	info_lbl.modulate = Color(0.7, 1.0, 0.7)
	info_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	info_lbl.clip_text = true
	toolbar.add_child(info_lbl)
	toolbar.move_child(info_lbl, 6)
	
	file_dialog = EditorFileDialog.new()
	file_dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILE
	file_dialog.add_filter("*.tres", "Quest Resource")
	file_dialog.file_selected.connect(_on_file_selected)
	EditorInterface.get_base_control().add_child(file_dialog)

# --- OBSŁUGA PLIKÓW ---
func _on_load_pressed() -> void:
	file_dialog.popup_centered_ratio(0.5)

func _on_file_selected(path: String) -> void:
	var res = load(path)
	if res and res is QuestData:
		load_from_inspector(res)
	else:
		printerr("Quest Editor: Nie można wczytać pliku lub to nie QuestData.")

func load_from_inspector(quest: QuestData) -> void:
	if not quest: return
	if quest.resource_path != "" and not "::" in quest.resource_path:
		current_file_path = quest.resource_path
		_resource_to_render = quest
		if not _render_queued:
			_render_queued = true
			call_deferred("_do_render")

# --- REAKCJA NA ZMIANY Z INSPEKTORA ---
func _on_node_resource_changed() -> void:
	if _is_typing: return 
	
	if not _refresh_queued:
		_refresh_queued = true
		call_deferred("_execute_refresh")

func _execute_refresh() -> void:
	_refresh_queued = false
	_save_layout() 
	_do_render()

func _on_refresh_pressed() -> void:
	if current_file_path != "":
		_save_layout()
		load_from_inspector(_resource_to_render)

func _on_edit_graph_pressed() -> void:
	if _resource_to_render:
		EditorInterface.edit_resource(_resource_to_render)

# --- INTELIGENTNE ROZMIESZCZANIE ---
func _smart_arrange_nodes() -> void:
	arrange_nodes()
	await get_tree().process_frame
	await get_tree().process_frame
	_save_layout()

# --- MENU KONTEKSTOWE I SKRÓTY ---
func _on_popup_request(pos: Vector2) -> void:
	if not _resource_to_render or current_file_path == "": return
	context_menu.set_item_disabled(1, _clipboard_nodes.is_empty())
	context_menu.position = get_screen_position() + pos
	context_menu.popup()

func _on_context_menu_pressed(id: int) -> void:
	var local_pos = (get_local_mouse_position() + scroll_offset) / zoom
	if id == 0:
		_add_new_node(local_pos)
	elif id == 1:
		_paste_nodes_at(local_pos)

func _on_node_context_menu_pressed(id: int) -> void:
	if id == 0:
		_on_copy_nodes_request()
	elif id == 1:
		_on_duplicate_nodes_request()

func _add_new_node(spawn_pos: Vector2) -> int:
	var quest = _resource_to_render
	var new_stage = QuestStage.new()
	quest.stages.append(new_stage)
	var new_idx = quest.stages.size() - 1
	var base_name = "Stage_" + str(new_idx)
	_pending_node_positions[base_name] = spawn_pos
	ResourceSaver.save(quest, current_file_path)
	_on_refresh_pressed()
	return new_idx

# --- KOPIOWANIE, WKLEJANIE I DUPLIKACJA ---
func _on_copy_nodes_request() -> void:
	if not _resource_to_render: return
	_clipboard_nodes.clear()
	for child in get_children():
		if child is GraphNode and child.selected and child.has_meta("stage_index"):
			var idx = child.get_meta("stage_index")
			if idx < _resource_to_render.stages.size():
				_clipboard_nodes.append(_resource_to_render.stages[idx].duplicate(true))

func _on_paste_nodes_request() -> void:
	var mouse_pos = (get_local_mouse_position() + scroll_offset) / zoom
	_paste_nodes_at(mouse_pos)

func _paste_nodes_at(pos: Vector2) -> void:
	if not _resource_to_render or _clipboard_nodes.is_empty(): return
	var quest = _resource_to_render
	for i in range(_clipboard_nodes.size()):
		var copied_stage = _clipboard_nodes[i].duplicate(true)
		quest.stages.append(copied_stage)
		var new_idx = quest.stages.size() - 1
		_pending_node_positions["Stage_" + str(new_idx)] = pos + Vector2(i * 50, i * 50)
	ResourceSaver.save(quest, current_file_path)
	_on_refresh_pressed()

func _on_duplicate_nodes_request() -> void:
	_on_copy_nodes_request()
	_on_paste_nodes_request()

# --- ZARZĄDZANIE KABLAMI ---
func _on_connection_request(from_node: StringName, from_port: int, to_node: StringName, to_port: int) -> void:
	connect_node(from_node, from_port, to_node, to_port)
	_rebuild_quest_stages_from_graph()

func _on_disconnection_request(from_node: StringName, from_port: int, to_node: StringName, to_port: int) -> void:
	disconnect_node(from_node, from_port, to_node, to_port)
	_rebuild_quest_stages_from_graph()

func _on_connection_to_empty(from_node: StringName, from_port: int, release_position: Vector2) -> void:
	if not _resource_to_render or current_file_path == "": return
	var local_pos = (release_position + scroll_offset) / zoom
	var new_idx = _add_new_node(local_pos)
	var to_node = StringName("Stage_" + str(new_idx) + "_" + str(render_generation))
	_on_connection_request(from_node, from_port, to_node, 0)

func _on_delete_nodes_request(nodes: Array[StringName]) -> void:
	if not _resource_to_render or current_file_path == "": return
	var quest = _resource_to_render
	var changed = false
	
	var indices_to_remove = []
	for n in nodes:
		var gnode = get_node_or_null(str(n))
		if gnode and gnode.has_meta("stage_index"):
			indices_to_remove.append(gnode.get_meta("stage_index"))
			
	indices_to_remove.sort()
	indices_to_remove.reverse()
	
	for idx in indices_to_remove:
		if idx < quest.stages.size():
			quest.stages.remove_at(idx)
			changed = true
			
	if changed:
		ResourceSaver.save(quest, current_file_path)
		_on_refresh_pressed()

func _rebuild_quest_stages_from_graph() -> void:
	if not _resource_to_render or current_file_path == "": return
	var quest = _resource_to_render
	var old_stages = quest.stages.duplicate()
	var new_stages: Array[QuestStage] = []
	var visited_indices: Array[int] = []
	
	var current_node_name = "MainNode_" + str(render_generation)
	var conns = get_connection_list()
	
	var has_next = true
	while has_next:
		has_next = false
		for c in conns:
			if c["from_node"] == current_node_name:
				var target_gnode = get_node_or_null(str(c["to_node"]))
				if target_gnode and target_gnode.has_meta("stage_index"):
					var idx = target_gnode.get_meta("stage_index")
					if idx < old_stages.size():
						new_stages.append(old_stages[idx])
						visited_indices.append(idx)
					current_node_name = c["to_node"]
					has_next = true
				break

	for i in range(old_stages.size()):
		if not visited_indices.has(i):
			new_stages.append(old_stages[i])
			
	quest.stages = new_stages
	ResourceSaver.save(quest, current_file_path)
	_on_refresh_pressed()

# --- SYSTEM LAYOUTU ---
func _save_layout() -> void:
	if current_file_path == "": return
	var layout_path = current_file_path + ".layout"
	var layout_data = {}
	for child in get_children():
		if child is GraphNode and child.has_meta("base_name"):
			layout_data[child.get_meta("base_name")] = {
				"pos_x": child.position_offset.x,
				"pos_y": child.position_offset.y,
				"size_x": child.size.x,
				"size_y": child.size.y
			}
	var file = FileAccess.open(layout_path, FileAccess.WRITE)
	if file: file.store_string(JSON.stringify(layout_data))

func _load_layout() -> void:
	if current_file_path == "": return
	var layout_path = current_file_path + ".layout"
	var layout_data = {}
	if FileAccess.file_exists(layout_path):
		var file = FileAccess.open(layout_path, FileAccess.READ)
		var json = JSON.new()
		if json.parse(file.get_as_text()) == OK:
			layout_data = json.data
			
	for child in get_children():
		if child is GraphNode and child.has_meta("base_name"):
			var b_name = child.get_meta("base_name")
			child.size = Vector2.ZERO # Wymusza skurczenie do zawartości
			if layout_data.has(b_name):
				var d = layout_data[b_name]
				child.position_offset = Vector2(d["pos_x"], d["pos_y"])
				if d.has("size_x"):
					child.size = Vector2(d["size_x"], d["size_y"])
			elif _pending_node_positions.has(b_name):
				child.position_offset = _pending_node_positions[b_name]
				_pending_node_positions.erase(b_name)


# --- WIZUALIZACJA GŁÓWNA ---
func _create_info_row(text_label: String, value_str: String, color: Color) -> HBoxContainer:
	var hbox = HBoxContainer.new()
	var lbl = Label.new()
	lbl.text = text_label
	lbl.modulate = Color(0.6, 0.6, 0.6)
	var val = Label.new()
	val.text = value_str
	val.modulate = color
	val.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	val.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	hbox.add_child(lbl)
	hbox.add_child(val)
	return hbox

# --- RYSOWANIE GRAFU ---
func _do_render() -> void:
	_render_queued = false
	if not _resource_to_render: return
	
	var quest = _resource_to_render
	render_generation += 1
	clear_connections()
	
	for child in get_children():
		if child is GraphNode or child is Label:
			if child.has_meta("quest_resource"):
				var res = child.get_meta("quest_resource")
				if res and res.changed.is_connected(_on_node_resource_changed):
					res.changed.disconnect(_on_node_resource_changed)
			remove_child(child)
			child.queue_free()
			
	await get_tree().process_frame
	
	if not quest.changed.is_connected(_on_node_resource_changed):
		quest.changed.connect(_on_node_resource_changed)
	
	# ==========================================
	# 1. GŁÓWNY WĘZEŁ ZADANIA (ZŁOTY)
	# ==========================================
	var main_node = GraphNode.new()
	main_node.name = "MainNode_" + str(render_generation)
	main_node.set_meta("base_name", "MainNode")
	main_node.set_meta("quest_resource", quest)
	main_node.title = "ZADANIE: " + quest.title
	main_node.self_modulate = Color(1.0, 0.85, 0.4)
	main_node.position_offset = Vector2(40, 100)
	
	main_node.resizable = true
	main_node.resize_request.connect(func(new_size): main_node.size = new_size)
	main_node.node_selected.connect(func(): EditorInterface.edit_resource(quest))
	
	var child_idx = 0
	
	# Pola ID
	var id_box = HBoxContainer.new()
	var id_lbl = Label.new()
	id_lbl.text = "ID:"
	var id_edit = LineEdit.new()
	id_edit.text = str(quest.id)
	id_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	id_edit.focus_entered.connect(func(): _is_typing = true)
	id_edit.focus_exited.connect(func(): 
		_is_typing = false
		if str(quest.id) != id_edit.text:
			quest.id = StringName(id_edit.text)
			ResourceSaver.save(quest, current_file_path)
			_on_refresh_pressed()
	)
	id_box.add_child(id_lbl)
	id_box.add_child(id_edit)
	main_node.add_child(id_box)
	main_node.set_slot(child_idx, false, 0, Color.WHITE, false, 0, Color.WHITE)
	child_idx += 1
	
	# Opis Zadania
	var desc_edit = TextEdit.new()
	desc_edit.text = quest.description
	desc_edit.custom_minimum_size = Vector2(300, 80)
	desc_edit.scroll_fit_content_height = true 
	desc_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	desc_edit.placeholder_text = "Opis zadania..."
	desc_edit.focus_entered.connect(func(): _is_typing = true)
	desc_edit.focus_exited.connect(func(): 
		_is_typing = false
		if quest.description != desc_edit.text:
			quest.description = desc_edit.text
			ResourceSaver.save(quest, current_file_path)
			_on_refresh_pressed()
	)
	main_node.add_child(desc_edit)
	main_node.set_slot(child_idx, false, 0, Color.WHITE, false, 0, Color.WHITE)
	child_idx += 1
	
	# --- NOWOŚĆ: Wizualizacja Kategori i Czasu ---
	var cat_str = "Main Story"
	match quest.category:
		QuestData.QuestCategory.SIDE_QUEST: cat_str = "Side Quest"
		QuestData.QuestCategory.CONTRACT: cat_str = "Contract"
		QuestData.QuestCategory.HIDDEN: cat_str = "Hidden"
	main_node.add_child(_create_info_row("Kategoria:", cat_str, Color(1, 0.8, 0.4)))
	main_node.set_slot(child_idx, false, 0, Color.WHITE, false, 0, Color.WHITE)
	child_idx += 1
	
	if quest.time_limit_seconds > 0.0:
		main_node.add_child(_create_info_row("Limit Czasu:", str(quest.time_limit_seconds) + " s", Color(1, 0.4, 0.4)))
		main_node.set_slot(child_idx, false, 0, Color.WHITE, false, 0, Color.WHITE)
		child_idx += 1
		
	# --- NOWOŚĆ: Wizualizacja Eventów ---
	if quest.completion_event != "":
		main_node.add_child(_create_info_row("Event Sukcesu:", quest.completion_event, Color(0.4, 1.0, 0.4)))
		main_node.set_slot(child_idx, false, 0, Color.WHITE, false, 0, Color.WHITE)
		child_idx += 1
		
	if quest.failure_event != "":
		main_node.add_child(_create_info_row("Event Porażki:", quest.failure_event, Color(1.0, 0.4, 0.4)))
		main_node.set_slot(child_idx, false, 0, Color.WHITE, false, 0, Color.WHITE)
		child_idx += 1
	
	main_node.add_child(HSeparator.new())
	main_node.set_slot(child_idx, false, 0, Color.WHITE, false, 0, Color.WHITE)
	child_idx += 1
	
	# --- NOWOŚĆ: Wizualizacja łańcucha ---
	var chain_box = HBoxContainer.new()
	var chain_lbl = Label.new()
	if quest.next_quest_in_chain:
		chain_lbl.text = "Następny w Łańcuchu: " + quest.next_quest_in_chain.resource_path.get_file()
		chain_lbl.modulate = Color(0.6, 0.8, 1.0)
		chain_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var clear_chain = Button.new()
		clear_chain.text = "X"
		clear_chain.modulate = Color(1.0, 0.4, 0.4)
		clear_chain.pressed.connect(func(): 
			quest.next_quest_in_chain = null
			ResourceSaver.save(quest, current_file_path)
			_on_refresh_pressed()
		)
		chain_box.add_child(chain_lbl)
		chain_box.add_child(clear_chain)
	else:
		chain_lbl.text = "Przebieg Etapów ->"
		chain_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		chain_lbl.modulate = Color(0.6, 1.0, 0.6)
		chain_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		chain_box.add_child(chain_lbl)
		
	main_node.add_child(chain_box)
	main_node.set_slot(child_idx, false, 0, Color.WHITE, true, 0, Color.GREEN)
	child_idx += 1
	
	add_child(main_node)
	
	# ==========================================
	# 2. WĘZŁY ETAPÓW (NIEBIESKIE)
	# ==========================================
	var stages = quest.stages
	for i in range(stages.size()):
		var stage = stages[i]
		if not stage: continue
		
		if not stage.changed.is_connected(_on_node_resource_changed):
			stage.changed.connect(_on_node_resource_changed)
		
		var s_node = GraphNode.new()
		var base_name = "Stage_" + str(i)
		s_node.name = base_name + "_" + str(render_generation)
		s_node.set_meta("base_name", base_name)
		s_node.set_meta("stage_index", i)
		s_node.set_meta("quest_resource", stage)
		s_node.title = "ETAP " + str(i)
		s_node.self_modulate = Color(0.4, 0.7, 1.0)
		s_node.position_offset = Vector2(450 + (i * 400), 100)
		
		s_node.resizable = true
		s_node.resize_request.connect(func(new_size): s_node.size = new_size)
		s_node.node_selected.connect(func(): EditorInterface.edit_resource(stage))
		
		s_node.gui_input.connect(func(event):
			if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
				for child in get_children():
					if child is GraphNode: child.selected = false
				s_node.selected = true
				node_context_menu.position = get_screen_position() + get_local_mouse_position()
				node_context_menu.popup()
		)
		
		var s_idx = 0
		
		var obj_edit = TextEdit.new()
		obj_edit.text = stage.objective_text
		obj_edit.custom_minimum_size = Vector2(300, 60)
		obj_edit.scroll_fit_content_height = true 
		obj_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
		obj_edit.placeholder_text = "Ogólny cel etapu..."
		obj_edit.focus_entered.connect(func(): _is_typing = true)
		obj_edit.focus_exited.connect(func(): 
			_is_typing = false
			if stage.objective_text != obj_edit.text:
				stage.objective_text = obj_edit.text
				ResourceSaver.save(quest, current_file_path)
				_on_refresh_pressed()
		)
		s_node.add_child(obj_edit)
		s_node.set_slot(s_idx, true, 0, Color.GREEN, true, 0, Color.GREEN)
		s_idx += 1
		
		# --- NOWOŚĆ: Wizualizacja Eventów Startowych ---
		if stage.trigger_event_on_start != "":
			s_node.add_child(_create_info_row("Wyzwalacz:", stage.trigger_event_on_start, Color(1.0, 0.4, 0.4)))
			s_node.set_slot(s_idx, false, 0, Color.WHITE, false, 0, Color.WHITE)
			s_idx += 1
			
		# --- NOWOŚĆ: Skrócona Lista Celów! ---
		if stage.objectives.size() > 0:
			var obj_box = VBoxContainer.new()
			var hdr = Label.new()
			hdr.text = "Cele (" + str(stage.objectives.size()) + "):"
			hdr.modulate = Color(0.8, 0.8, 0.8)
			obj_box.add_child(hdr)
			
			for obj in stage.objectives:
				if obj:
					var l = Label.new()
					l.text = " • " + obj.objective_description
					if l.text == " • ": l.text = " • [Brak Opisu]"
					l.modulate = Color(0.8, 1.0, 0.8)
					obj_box.add_child(l)
					
			s_node.add_child(obj_box)
			s_node.set_slot(s_idx, false, 0, Color.WHITE, false, 0, Color.WHITE)
			s_idx += 1
		
		s_node.add_child(HSeparator.new())
		s_node.set_slot(s_idx, false, 0, Color.WHITE, false, 0, Color.WHITE)
		s_idx += 1
		
		var edit_objs_btn = Button.new()
		var obj_count = stage.objectives.size()
		var rew_count = stage.start_rewards.size()
		edit_objs_btn.text = "🔍 Inspektor: Cele (%d) | Nagrody (%d)" % [obj_count, rew_count]
		if obj_count > 0 or rew_count > 0:
			edit_objs_btn.modulate = Color(1.0, 0.8, 0.4)
		else:
			edit_objs_btn.modulate = Color(0.7, 0.7, 0.7)
		edit_objs_btn.pressed.connect(func(): EditorInterface.edit_resource(stage))
		s_node.add_child(edit_objs_btn)
		s_node.set_slot(s_idx, false, 0, Color.WHITE, false, 0, Color.WHITE)
		s_idx += 1
		
		var del_btn = Button.new()
		del_btn.text = "❌ Usuń ten Etap"
		del_btn.modulate = Color(1.0, 0.4, 0.4)
		del_btn.flat = true
		del_btn.pressed.connect(func(): _on_delete_nodes_request([StringName(s_node.name)]))
		s_node.add_child(del_btn)
		s_node.set_slot(s_idx, false, 0, Color.WHITE, false, 0, Color.WHITE)
		s_idx += 1
		
		add_child(s_node)

	if stages.size() > 0:
		connect_node(main_node.name, 0, "Stage_0_" + str(render_generation), 0)
		for i in range(stages.size() - 1):
			var from_name = "Stage_" + str(i) + "_" + str(render_generation)
			var to_name = "Stage_" + str(i + 1) + "_" + str(render_generation)
			connect_node(from_name, 0, to_name, 0)
			
	_load_layout()
