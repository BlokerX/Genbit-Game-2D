@tool
extends GraphEdit

var current_file_path: String = ""
var render_generation: int = 0
var _render_queued: bool = false
var _resource_to_render: Resource = null
var file_dialog: EditorFileDialog

func _ready() -> void:
	right_disconnects = false
	connection_request.connect(func(fn, fp, tn, tp): pass)
	disconnection_request.connect(func(fn, fp, tn, tp): pass)
	
	var toolbar = get_menu_hbox()
	
	var load_btn = Button.new()
	load_btn.text = "📂 Wczytaj plik ręcznie"
	load_btn.pressed.connect(_on_load_pressed)
	toolbar.add_child(load_btn)
	toolbar.move_child(load_btn, 0)
	
	var refresh_btn = Button.new()
	refresh_btn.text = "🔄 Odśwież Graf"
	refresh_btn.pressed.connect(_on_refresh_pressed)
	toolbar.add_child(refresh_btn)
	toolbar.move_child(refresh_btn, 1)
	
	var save_btn = Button.new()
	save_btn.text = "💾 Zapisz Układ"
	save_btn.pressed.connect(_save_layout)
	toolbar.add_child(save_btn)
	toolbar.move_child(save_btn, 2)
	
	var reset_btn = Button.new()
	reset_btn.text = "🗑️ Reset Układu"
	reset_btn.pressed.connect(_reset_layout)
	toolbar.add_child(reset_btn)
	toolbar.move_child(reset_btn, 3)
	
	var arrange_btn = Button.new()
	arrange_btn.text = "✨ Auto-Rozmieść"
	arrange_btn.pressed.connect(arrange_nodes)
	toolbar.add_child(arrange_btn)
	toolbar.move_child(arrange_btn, 4)
	
	var sep = VSeparator.new()
	toolbar.add_child(sep)
	toolbar.move_child(sep, 5)
	
	var info_lbl = Label.new()
	info_lbl.text = " Podgląd Grafu (Tylko do odczytu) "
	info_lbl.modulate = Color(0.7, 0.7, 1.0)
	info_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	info_lbl.clip_text = true
	toolbar.add_child(info_lbl)
	toolbar.move_child(info_lbl, 6)
	
	file_dialog = EditorFileDialog.new()
	file_dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILE
	file_dialog.add_filter("*.tres", "Dialogue Resource")
	file_dialog.file_selected.connect(_on_file_selected)
	EditorInterface.get_base_control().add_child(file_dialog)

func _on_load_pressed() -> void:
	file_dialog.popup_centered_ratio(0.5)

func _on_refresh_pressed() -> void:
	if current_file_path != "" and ResourceLoader.exists(current_file_path):
		var res = load(current_file_path)
		if res: load_from_inspector(res)

func _on_file_selected(path: String) -> void:
	var res = load(path)
	if res:
		load_from_inspector(res)
	else:
		printerr("Podgląd: Nie można wczytać pliku.")

func load_from_inspector(graph: Resource) -> void:
	if not graph: return
	if graph.resource_path != "" and not "::" in graph.resource_path:
		current_file_path = graph.resource_path
		
	_resource_to_render = graph
	
	if not _render_queued:
		_render_queued = true
		call_deferred("_do_render")

func _do_render() -> void:
	_render_queued = false
	if _resource_to_render:
		_render_graph(_resource_to_render)

func _render_graph(graph: Resource) -> void:
	render_generation += 1
	
	clear_connections()
	for child in get_children():
		if child is GraphNode or child is Label:
			remove_child(child)
			child.queue_free()
			
	await get_tree().process_frame

	var nodes_dict = graph.get("nodes")
	if nodes_dict == null:
		var err_lbl = Label.new()
		err_lbl.text = "WYBRANY PLIK NIE JEST GRAFEM (DialogueGraph).\nUżyj skryptu konwertera, aby zmigrować ten stary zasób."
		err_lbl.modulate = Color.RED
		err_lbl.position = Vector2(50, 50)
		add_child(err_lbl)
		return
		
	if typeof(nodes_dict) != TYPE_DICTIONARY:
		return

	var start_id = str(graph.get("start_node_id"))
	var fallback_index = 0
	
	# PASS 1: Generowanie klocków
	for node_id in nodes_dict:
		var d_node = nodes_dict[node_id]
		if not d_node: continue
		
		var g_node = GraphNode.new()
		var n_id_str = str(node_id)
		
		var actual_node_name = n_id_str + "_" + str(render_generation) 
		
		g_node.name = actual_node_name
		g_node.set_meta("base_name", n_id_str)
		g_node.resizable = true
		g_node.resize_request.connect(func(new_size): g_node.size = new_size)
		
		var grid_x = (fallback_index % 3) * 480
		var grid_y = int(fallback_index / 3) * 350
		g_node.position_offset = Vector2(grid_x, grid_y)
		fallback_index += 1
		
		var title_str = "▶ " + n_id_str
		var speaker_res = d_node.get("speaker")
		if speaker_res and speaker_res.get("speaker_name") != null:
			title_str += " (" + str(speaker_res.get("speaker_name")) + ")"
			
		var is_start = (n_id_str == start_id)
		if is_start: 
			title_str = "⭐ START: " + title_str
			g_node.self_modulate = Color(0.8, 1.0, 0.8) 
			
		g_node.title = title_str

		var child_idx = 0
		var in_port_set = false

		if speaker_res:
			_build_speaker_ui(g_node, speaker_res)
			g_node.set_slot(child_idx, not in_port_set, 0, Color.WHITE, false, 0, Color.WHITE)
			in_port_set = true
			child_idx += 1

		if is_start:
			var file_lbl = Label.new()
			file_lbl.text = "Plik:\n" + current_file_path.get_file()
			file_lbl.modulate = Color(0.6, 0.9, 0.6)
			g_node.add_child(file_lbl)
			g_node.set_slot(child_idx, not in_port_set, 0, Color.WHITE, false, 0, Color.WHITE)
			in_port_set = true
			child_idx += 1
			
		var text_edit = TextEdit.new()
		text_edit.text = str(d_node.get("dialogue_text"))
		text_edit.custom_minimum_size = Vector2(320, 80)
		text_edit.editable = false
		text_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
		g_node.add_child(text_edit)
		
		g_node.set_slot(child_idx, not in_port_set, 0, Color.WHITE, false, 0, Color.WHITE)
		in_port_set = true
		child_idx += 1
		
		var skip_time = d_node.get("min_skip_time")
		if skip_time == null: skip_time = 0.5
		var allow_cancel = d_node.get("allow_cancel")
		if allow_cancel == null: allow_cancel = false
		
		var params_lbl = Label.new()
		params_lbl.text = "Min. Skip: " + str(skip_time) + "s | Cancel: " + str(allow_cancel).to_lower()
		params_lbl.modulate = Color.GRAY
		g_node.add_child(params_lbl)
		g_node.set_slot(child_idx, false, 0, Color.WHITE, false, 0, Color.WHITE)
		child_idx += 1
		
		var outputs = d_node.get("outputs")
		if outputs and typeof(outputs) == TYPE_ARRAY and outputs.size() > 0:
			for conn in outputs:
				if conn == null: continue
				
				var out_lbl = Label.new()
				var conn_text = str(conn.get("text"))
				
				if conn_text != "":
					out_lbl.text = "➔ Wybór: " + conn_text
					out_lbl.modulate = Color.YELLOW
				else:
					out_lbl.text = "➔ Dalej"
					
				var conds = conn.get("conditions")
				var effs = conn.get("consequences")
				var c_size = conds.size() if (conds and typeof(conds) == TYPE_ARRAY) else 0
				var e_size = effs.size() if (effs and typeof(effs) == TYPE_ARRAY) else 0
				
				if c_size > 0 or e_size > 0:
					out_lbl.text += " [C:%d|E:%d]" % [c_size, e_size]
					out_lbl.modulate = Color(1.0, 0.8, 0.4)
					
				out_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
				g_node.add_child(out_lbl)
				g_node.set_slot(child_idx, false, 0, Color.WHITE, true, 0, Color.YELLOW if conn_text != "" else Color.WHITE)
				child_idx += 1
		else:
			var end_lbl = Label.new()
			end_lbl.text = "⬛ Koniec"
			end_lbl.modulate = Color(0.5, 0.5, 0.5)
			end_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			g_node.add_child(end_lbl)
			g_node.set_slot(child_idx, false, 0, Color.WHITE, false, 0, Color.WHITE)
			child_idx += 1
		
		if allow_cancel:
			var cancel_lbl = Label.new()
			cancel_lbl.text = "✖ Opuść dialog (Anuluj)"
			cancel_lbl.modulate = Color(1.0, 0.4, 0.4)
			cancel_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			g_node.add_child(cancel_lbl)
			g_node.set_slot(child_idx, false, 0, Color.WHITE, true, 0, Color.RED)
			child_idx += 1

		add_child(g_node)

	# PASS 2: Łączenie krawędzi (Cykle)
	for node_id in nodes_dict:
		var d_node = nodes_dict[node_id]
		if not d_node: continue
		
		var outputs = d_node.get("outputs")
		if outputs and typeof(outputs) == TYPE_ARRAY:
			var valid_out_index = 0
			for conn in outputs:
				if conn == null: continue
				var target_id_str = str(conn.get("target_id"))
				if target_id_str != "" and nodes_dict.has(StringName(target_id_str)):
					var from_name = str(node_id) + "_" + str(render_generation)
					var to_name = target_id_str + "_" + str(render_generation)
					connect_node(from_name, valid_out_index, to_name, 0)
				valid_out_index += 1

	_load_layout()

func _build_speaker_ui(gnode: GraphNode, speaker: Resource) -> void:
	if not speaker: return
	var hbox = HBoxContainer.new()
	var tex_rect = TextureRect.new()
	var portrait = speaker.get("portrait")
	if portrait:
		tex_rect.texture = portrait
		tex_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		tex_rect.custom_minimum_size = Vector2(40, 40)
	
	var name_lbl = RichTextLabel.new()
	name_lbl.bbcode_enabled = true
	var s_name = str(speaker.get("speaker_name"))
	var s_color = speaker.get("name_color")
	if typeof(s_color) == TYPE_COLOR:
		name_lbl.text = "[b][color=#" + s_color.to_html() + "]" + s_name + "[/color][/b]"
	else:
		name_lbl.text = "[b]" + s_name + "[/b]"
	
	name_lbl.custom_minimum_size = Vector2(150, 40)
	
	hbox.add_child(tex_rect)
	hbox.add_child(name_lbl)
	gnode.add_child(hbox)

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
	file.store_string(JSON.stringify(layout_data))
	print("PK Dialogues: Zapisano układ podglądu.")

func _load_layout() -> void:
	if current_file_path == "": return
	var layout_path = current_file_path + ".layout"
	if not FileAccess.file_exists(layout_path): return
	var file = FileAccess.open(layout_path, FileAccess.READ)
	var json = JSON.new()
	if json.parse(file.get_as_text()) == OK:
		var layout_data = json.data
		for child in get_children():
			if child is GraphNode and child.has_meta("base_name"):
				var b_name = child.get_meta("base_name")
				if layout_data.has(b_name):
					var d = layout_data[b_name]
					child.position_offset = Vector2(d["pos_x"], d["pos_y"])
					child.size = Vector2(d["size_x"], d["size_y"])

func _reset_layout() -> void:
	if current_file_path == "": return
	var layout_path = current_file_path + ".layout"
	if FileAccess.file_exists(layout_path):
		var err = DirAccess.remove_absolute(layout_path)
		if err == OK:
			print("PK Dialogues: Usunięto plik layoutu.")
			_on_refresh_pressed()
