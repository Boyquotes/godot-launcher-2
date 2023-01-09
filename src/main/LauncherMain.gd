extends Control

const conf = {
	"info_url": "https://osakitsukiko.github.io/holy-grail/launcher/info.json",
	"platform": "linux" # linux | win | osx
}

onready var networking = $Networking
onready var dwl_http_req = $Networking/DwlHTTPReq

onready var error_cont = $Error
onready var error_label = $Error/CenterContainer/VBoxContainer/ErrorLabel

onready var progress_bar = $Main/VBoxContainer/ProgressBar
onready var dwl_update_btn = $Main/VBoxContainer/MarginContainer/VBoxContainer/HBoxContainer/DWLUpdateBTN
onready var play_btn = $Main/VBoxContainer/MarginContainer/VBoxContainer/HBoxContainer/PlayBTN
onready var rdwl_btn = $Main/VBoxContainer/MarginContainer/VBoxContainer/HBoxContainer/RDWLBTN

var process_dwl = false

var game_info = {
	"pck": "",
	"main_scene": "",
	"version": ""
}

func _ready():
	error_cont.visible = false
	dwl_update_btn.visible = false
	play_btn.visible = false
	rdwl_btn.visible = false
	progress_bar.visible = false
	
	var s = load_save("info")
	if (s != null):
		var s_ok = true
		for key in game_info:
			if !s.has(key):
				s_ok = false
				break
		if (s_ok):
			game_info = s
	
	for key in game_info:
		print(key)
	
	if (conf.info_url == ""):
		show_error("Invalid Config!")
		return
	var err = make_http_req(
		"request_info",
		conf.info_url,
		[],
		true,
		HTTPClient.METHOD_GET,
		{}
	)
	if (!err):
		show_error("Request Failed!")
		return

func request_info(result, response_code, headers, body, req_node):
	req_node.queue_free()
	if (response_code == 200):
		var json: Dictionary = parse_json(body.get_string_from_utf8())
		if (!json.has(conf.platform)):
			show_error("Platform NOT Supported!")
			return
		if (!json[conf.platform].has_all(["pck", "main_scene", "version"])):
			show_error("Invalid Response!")
			return
		if (
			game_info["version"] == json[conf.platform]["version"] &&
			game_info["main_scene"] == json[conf.platform]["main_scene"] &&
			game_info["pck"] == json[conf.platform]["pck"]
		):
			play_btn.visible = true
			rdwl_btn.visible = true
			return
		game_info["pck"] = json[conf.platform]["pck"]
		game_info["main_scene"] = json[conf.platform]["main_scene"]
		game_info["version"] = json[conf.platform]["version"]
		dwl_update_btn.visible = true
	else:
		show_error("Failed to connect to server! " + String(response_code))
		# TODO: Show more explicit errors
		return

func _on_DwlHTTPReq_completed(result, response_code, headers, body):
	process_dwl = false
	if (response_code != 200):
		show_error("Unable to download files from mirror! " + String(response_code))
		return
	save(game_info, "info")
	progress_bar.value = 100
	progress_bar.visible = false
	dwl_update_btn.visible = false
	dwl_update_btn.disabled = false
	rdwl_btn.disabled = false
	play_btn.visible = true
	rdwl_btn.visible = true

func _process(delta):
	if (process_dwl):
		progress_bar.value = dwl_http_req.get_downloaded_bytes()*100/dwl_http_req.get_body_size()

func _on_DWLUpdateBTN_pressed():
	dwl_update_btn.disabled = true
	dwl_http_req.set_download_file("user://game.pck")
	dwl_http_req.request(game_info["pck"])
	progress_bar.visible = true
	process_dwl = true

func _on_RDWLBTN_pressed():
	play_btn.visible = false
	rdwl_btn.disabled = true
	dwl_http_req.set_download_file("user://game.pck")
	dwl_http_req.request(game_info["pck"])
	progress_bar.visible = true
	process_dwl = true

func _on_PlayBTN_pressed():
	load_pck("user://game.pck", game_info["main_scene"])

# Utils

func make_http_req(resp_handler: String, url: String, headers: Array, secure, method, req_body: Dictionary) -> bool:
	var http_req_node: HTTPRequest = HTTPRequest.new()
	http_req_node.use_threads = true
	networking.add_child(http_req_node)
	http_req_node.connect("request_completed", self, resp_handler, [http_req_node])
	var err = http_req_node.request(
		url, 
		headers, 
		secure, 
		method, 
		to_json(req_body)
	)
	if err == OK:
		return true
	return false

func load_pck(path: String, autoscene: String = "", hard_load: bool = true) -> bool:
	var success = ProjectSettings.load_resource_pack(path, hard_load)
	if (!success):
		return success
	if (autoscene != ""):
		get_tree().change_scene_to(load(autoscene))
	return success

func show_error(error_message: String):
	error_label.text = error_message
	error_cont.visible = true

func save(data, file_name: String):
	var f := File.new()
	f.open("user://" + file_name + ".save", File.WRITE)
	f.store_buffer(var2bytes(data))
	f.close()

func load_save(file_name: String):
	var s = null
	var f := File.new()
	if f.file_exists("user://" + file_name + ".save"):
		f.open("user://" + file_name + ".save", File.READ)
		s = bytes2var(f.get_buffer(f.get_len()))
	f.close()
	return s
