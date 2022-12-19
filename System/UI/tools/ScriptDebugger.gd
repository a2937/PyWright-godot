extends Control

var current_stack
var look_at   # Set to a script if we are looking at something other than the current script

var script_tab
var popup_menu

var scripts = []

var in_debugger = false
var debug_last_state = null

# {"script": WrightScript, "editor": TextEdit, "highlighted_line":int, "bookmark_line": int}

func _ready():
	script_tab = get_node("Scripts/CurrentScript")
	$Scripts.remove_child(script_tab)
	$Step.connect("button_up", self, "step")
	$Pause.connect("button_up", self, "start_debugger")
	$AllEv.connect("button_up", self, "all_ev")
	$Reload.connect("button_up", self, "reload")
	
func reload():
	current_stack.clear_scripts()
	current_stack.blockers = []
	get_tree().change_scene("res://Main.tscn")
	
func start_debugger(force=false):
	if in_debugger:
		if force == false:
			in_debugger = false
			$Pause.text = "Pause"
			current_stack.disconnect("line_executed", self, "debug_line")
			current_stack.state = current_stack.STACK_READY
	else:
		in_debugger = true
		$Pause.text = "Resume"
		current_stack.connect("line_executed", self, "debug_line")
		current_stack.state = current_stack.STACK_DEBUG
		
func goto_line(row, scripti):
	if current_stack.scripts:
		current_stack.scripts[scripti].goto_line_number(row)
		current_stack.force_clear_blockers()
	scripts[scripti]["editor"].set_line_as_breakpoint(row, false)
	
func all_ev():
	for var_key in current_stack.variables.evidence_keys():
		Commands.call_command("addev", current_stack.scripts[-1], [var_key])
	
func debug_line(line):
	print("watching line", line)
	debug_last_state = current_stack.state
	current_stack.state = current_stack.STACK_DEBUG
	
func step():
	if in_debugger:
		current_stack.state = current_stack.STACK_READY
		
func rebuild():
	for child in $Scripts.get_children():
		$Scripts.remove_child(child)
		child.queue_free()
	scripts = []
	var i = 0
	for ii in range(len(current_stack.scripts)):
		var script = current_stack.scripts[current_stack.scripts.size()-1-ii]
		var d = {
			"script": script, 
			"editor": script_tab.duplicate(),
			"highlighted_line": null,
			"bookmark_line": null}
		d["editor"].name = "x"
		$Scripts.add_child(d["editor"])
		$Scripts.set_tab_title(i, script.filename)
		d["editor"].text = PoolStringArray(d["script"].lines).join("\n")
		d["editor"].connect("text_changed", self, "edit_script", [i])
		d["editor"].connect("breakpoint_toggled", self, "goto_line", [i])
		d["editor"].connect("info_clicked", self, "goto_line", [i])
		scripts.append(d)
		i += 1
	while scripts.size() > current_stack.scripts.size():
		var last = scripts.pop_back()
		$Scripts.remove_child(last["editor"])
		last["editor"].queue_free()
	$Scripts.current_tab = 0
	
func edit_script(script_index):
	var d = scripts[script_index]
	d["script"].load_string(d["editor"].text)
	d["script"].stack.show_in_debugger()

func update_current_stack(stack):
	if current_stack != stack:
		current_stack = stack
		current_stack.connect("enter_debugger", self, "start_debugger", [true])
	# Detect if scripts changed
	if len(scripts) != len(stack.scripts):
		rebuild()
	else:
		for i in range(len(scripts)):
			if scripts[i]["script"] != stack.scripts[stack.scripts.size()-1-i]:
				rebuild()
				break
	# Update each editor
	for i in range(len(scripts)):
		var to_line = scripts[i]["script"].line_num
		var at_line = scripts[i]["editor"].cursor_get_line()
		if to_line >= scripts[i]["editor"].get_line_count():
			to_line = at_line
		if scripts[i]["highlighted_line"] != to_line:
			scripts[i]["highlighted_line"] = to_line
			scripts[i]["editor"].cursor_set_line(to_line)
		if scripts[i]["bookmark_line"]!=null and scripts[i]["editor"].is_line_set_as_bookmark(scripts[i]["bookmark_line"]):
			scripts[i]["editor"].set_line_as_bookmark(scripts[i]["bookmark_line"], false)
		scripts[i]["editor"].set_line_as_bookmark(to_line, true)
		scripts[i]["bookmark_line"] = to_line


# TODO Whoops, I'm hooking up an event to control rather than to the script editor
var COPY = 0
func _input(evt:InputEvent):
	if evt is InputEventMouseButton:
		if evt.button_index == 2:
			var popup_menu = PopupMenu.new()
			popup_menu.add_item("Copy", COPY)
			popup_menu.connect("id_pressed", self, "menu_id_pressed")
			
func menu_id_pressed(id):
	if id == COPY:
		pass
