@tool
extends GraphEdit

var current_file_path: String = ""
var visited_nodes: Dictionary = {}
var node_y_counter: float = 0.0

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
	refresh_btn.text = "🔄 Odśwież"
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
	arrange_btn.pressed.connect(_arrange_graph)
	toolbar.add_child(arrange_btn)
	toolbar.move_child(arrange_btn, 4)
	
	var sep = VSeparator.new()
	toolbar.add_child(sep)
	toolbar.move_child(sep, 5)
	
	var info_lbl = Label.new()
	info_lbl.text = " Podgląd z Inspektora "
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

func load_from_inspector(branch: Resource) -> void:
	if not branch: return
	current_file_path = branch.resource_path
	_render_graph(branch)

func _render_graph(branch: Resource) -> void:
	clear_connections()
	for child in get_children():
		if child is GraphNode:
			remove_child(child)
			child.queue_free()
	
	await get_tree().process_frame
	
	visited_nodes.clear()
	node_y_counter = 0.0
	
	_traverse(branch, "", 0, 0)
	_load_layout()

func _get_stable_id(res: Resource) -> String:
	var t = res.get("dialogue_text")
	if t != null: return str(t).md5_text().substr(0, 10)
	var ct = res.get("choice_text")
	if ct != null: return str(ct).md5_text().substr(0, 10)
	return str(res.get_instance_id())

func _traverse(res: Resource, parent_name: String, parent_port: int, depth: int) -> String:
	if not res: return ""
	
	if visited_nodes.has(res):
		if parent_name != "":
			connect_node(parent_name, parent_port, visited_nodes[res], 0)
		return visited_nodes[res]
		
	var gnode = GraphNode.new()
	var node_name = "Node_" + _get_stable_id(res)
	gnode.name = node_name
	gnode.resizable = true
	gnode.resize_request.connect(func(new_size): gnode.size = new_size)
	add_child(gnode)
	
	visited_nodes[res] = node_name
	gnode.position_offset = Vector2(depth * 480, node_y_counter * 280)
	
	var script_path = ""
	if res.get_script():
		script_path = res.get_script().resource_path.get_file()

	if "dialogue_branch" in script_path:
		gnode.title = "▶ START Kaskady"
		
		var lbl = Label.new()
		lbl.text = "Plik:\n" + current_file_path.get_file()
		lbl.modulate = Color(0.6, 0.9, 0.6)
		gnode.add_child(lbl)
		gnode.set_slot(gnode.get_child_count() - 1, false, 0, Color.WHITE, true, 0, Color.GREEN)
		
		node_y_counter += 1
		if res.get("start_line"):
			var child_name = _traverse(res.get("start_line"), node_name, 0, depth + 1)
			if child_name != "": connect_node(node_name, 0, child_name, 0)
			
	elif "dialogue_line" in script_path:
		gnode.title = "▶ START (Linia Dialogowa)" if depth == 0 else "Linia Dialogowa"
		var current_out_port = 0
		var in_port_set = false
		
		var speaker_res = res.get("speaker")
		if speaker_res:
			_build_speaker_ui(gnode, speaker_res)
			gnode.set_slot(gnode.get_child_count() - 1, depth != 0 and not in_port_set, 0, Color.WHITE, false, 0, Color.WHITE)
			in_port_set = true
		
		var text_edit = TextEdit.new()
		text_edit.text = str(res.get("dialogue_text"))
		text_edit.custom_minimum_size = Vector2(320, 80)
		text_edit.editable = false
		text_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
		gnode.add_child(text_edit)
		if port_idx_check(in_port_set): 
			gnode.set_slot(gnode.get_child_count() - 1, depth != 0 and not in_port_set, 0, Color.WHITE, false, 0, Color.WHITE)
			in_port_set = true
		
		var params_lbl = Label.new()
		params_lbl.text = "Min. Skip Time: " + str(res.get("min_skip_time")) + "s | Allow Cancel: " + str(res.get("allow_cancel"))
		params_lbl.modulate = Color.GRAY
		gnode.add_child(params_lbl)
		gnode.set_slot(gnode.get_child_count() - 1, false, 0, Color.WHITE, false, 0, Color.WHITE)
		
		node_y_counter += 1
		
		var choices = res.get("choices")
		if choices != null and choices.size() > 0:
			for i in range(choices.size()):
				var c_lbl = Label.new()
				c_lbl.text = "➔ Wybór: " + str(choices[i].get("choice_text"))
				c_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
				gnode.add_child(c_lbl)
				gnode.set_slot(gnode.get_child_count() - 1, false, 0, Color.WHITE, true, 0, Color.YELLOW)
				
				var child_name = _traverse(choices[i], node_name, current_out_port, depth + 1)
				if child_name != "": connect_node(node_name, current_out_port, child_name, 0)
				current_out_port += 1
		else:
			var next_line = res.get("next_line")
			if next_line:
				var next_lbl = Label.new()
				next_lbl.text = "➔ Dalej"
				next_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
				gnode.add_child(next_lbl)
				gnode.set_slot(gnode.get_child_count() - 1, false, 0, Color.WHITE, true, 0, Color.WHITE)
				
				var child_name = _traverse(next_line, node_name, current_out_port, depth + 1)
				if child_name != "": connect_node(node_name, current_out_port, child_name, 0)
				current_out_port += 1
			else:
				var end_lbl = Label.new()
				end_lbl.text = "⬛ Koniec"
				end_lbl.modulate = Color(0.5, 0.5, 0.5)
				end_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
				gnode.add_child(end_lbl)
				gnode.set_slot(gnode.get_child_count() - 1, false, 0, Color.WHITE, false, 0, Color.WHITE)

		if res.get("allow_cancel"):
			var cancel_lbl = Label.new()
			cancel_lbl.text = "✖ Opuść dialog (Anuluj)"
			cancel_lbl.modulate = Color(1.0, 0.4, 0.4)
			cancel_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			gnode.add_child(cancel_lbl)
			gnode.set_slot(gnode.get_child_count() - 1, false, 0, Color.WHITE, true, 0, Color.RED)
			current_out_port += 1

	elif "dialogue_choice" in script_path:
		gnode.title = "▶ START (Wybór)" if depth == 0 else "Wybór"
		var current_out_port = 0
		var in_port_set = false
		
		var speaker_res = res.get("custom_speaker")
		if speaker_res:
			_build_speaker_ui(gnode, speaker_res)
			gnode.set_slot(gnode.get_child_count() - 1, depth != 0 and not in_port_set, 0, Color.YELLOW, false, 0, Color.WHITE)
			in_port_set = true
		
		var lbl = Label.new()
		lbl.text = str(res.get("choice_text"))
		lbl.custom_minimum_size = Vector2(250, 40)
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
		gnode.add_child(lbl)
		if port_idx_check(in_port_set):
			gnode.set_slot(gnode.get_child_count() - 1, depth != 0 and not in_port_set, 0, Color.YELLOW, false, 0, Color.WHITE)
			in_port_set = true
		
		var conds = res.get("conditions")
		if conds and conds.size() > 0:
			var cond_lbl = Label.new()
			cond_lbl.text = "🔒 Warunki: " + str(conds.size())
			cond_lbl.modulate = Color(1.0, 0.7, 0.3)
			gnode.add_child(cond_lbl)
			gnode.set_slot(gnode.get_child_count() - 1, false, 0, Color.WHITE, false, 0, Color.WHITE)
			
		var effs = res.get("effects")
		if not effs: effs = res.get("consequences")
		if effs and effs.size() > 0:
			var eff_lbl = Label.new()
			eff_lbl.text = "⚡ Efekty: " + str(effs.size())
			eff_lbl.modulate = Color(0.4, 0.8, 1.0)
			gnode.add_child(eff_lbl)
			gnode.set_slot(gnode.get_child_count() - 1, false, 0, Color.WHITE, false, 0, Color.WHITE)
		
		node_y_counter += 1
		
		var next_line = res.get("next_line")
		if next_line:
			var next_lbl = Label.new()
			next_lbl.text = "➔ Konsekwencja (Dalej)"
			next_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			gnode.add_child(next_lbl)
			gnode.set_slot(gnode.get_child_count() - 1, false, 0, Color.WHITE, true, 0, Color.WHITE)
			
			var child_name = _traverse(next_line, node_name, current_out_port, depth + 1)
			if child_name != "": connect_node(node_name, current_out_port, child_name, 0)
			current_out_port += 1
		else:
			var end_lbl = Label.new()
			end_lbl.text = "⬛ Koniec po wyborze"
			end_lbl.modulate = Color(0.5, 0.5, 0.5)
			end_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			gnode.add_child(end_lbl)
			gnode.set_slot(gnode.get_child_count() - 1, false, 0, Color.WHITE, false, 0, Color.WHITE)

	elif "speaker" in script_path:
		gnode.title = "Postać (Speaker)"
		_build_speaker_ui(gnode, res)
		gnode.set_slot(gnode.get_child_count() - 1, depth != 0, 0, Color.WHITE, false, 0, Color.WHITE)
		
		var info = Label.new()
		info.text = "Podgląd danych postaci."
		info.modulate = Color.GRAY
		gnode.add_child(info)
		gnode.set_slot(gnode.get_child_count() - 1, false, 0, Color.WHITE, false, 0, Color.WHITE)
		node_y_counter += 1

	return node_name

func port_idx_check(val: bool) -> bool:
	return true

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

func _arrange_graph() -> void:
	arrange_nodes()

func _reset_layout() -> void:
	if current_file_path == "": return
	var layout_path = current_file_path + ".layout"
	if FileAccess.file_exists(layout_path):
		var err = DirAccess.remove_absolute(layout_path)
		if err == OK:
			print("PK Dialogues: Usunięto plik layoutu.")
			_on_refresh_pressed()

func _save_layout() -> void:
	if current_file_path == "": return
	var layout_path = current_file_path + ".layout"
	
	var layout_data = {}
	for child in get_children():
		if child is GraphNode:
			layout_data[child.name] = {
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
			if child is GraphNode and layout_data.has(child.name):
				var d = layout_data[child.name]
				child.position_offset = Vector2(d["pos_x"], d["pos_y"])
				child.size = Vector2(d["size_x"], d["size_y"])
