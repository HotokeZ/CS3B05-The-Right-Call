class_name SafeScapeConsoleOverlay
extends CanvasLayer

## Developer / Evaluation Console Overlay for SafeScape 2.0
## Hidden by default. Toggle with ~ (Tilde/Backquote), F12, or Ctrl+Shift+D.
## Provides diagnostic logging, developer testing commands (finish_call, end_shift),
## and developer-only software performance and stability monitoring.

@onready var panel: PanelContainer = $Panel
@onready var tabs: TabContainer = get_node_or_null("Panel/VBox/Tabs")
@onready var log_display: TextEdit = get_node_or_null("Panel/VBox/Tabs/Evaluation Logs/Scroll/LogDisplay")
@onready var perf_log_display: TextEdit = get_node_or_null("Panel/VBox/Tabs/Performance Monitor/PerfScroll/PerfContent/PerfLogDisplay")

# Header buttons
@onready var close_btn: Button = $Panel/VBox/Header/CloseBtn
@onready var finish_call_btn: Button = get_node_or_null("Panel/VBox/Header/FinishCallBtn")
@onready var end_shift_btn: Button = get_node_or_null("Panel/VBox/Header/EndShiftBtn")
@onready var reset_bkt_btn: Button = $Panel/VBox/Header/ResetBktBtn
@onready var copy_btn: Button = $Panel/VBox/Header/CopyBtn
@onready var clear_btn: Button = $Panel/VBox/Header/ClearBtn

# Performance Toolbar buttons
@onready var perf_start_btn: Button = get_node_or_null("Panel/VBox/Tabs/Performance Monitor/PerfToolbar/PerfStartBtn")
@onready var perf_stop_btn: Button = get_node_or_null("Panel/VBox/Tabs/Performance Monitor/PerfToolbar/PerfStopBtn")
@onready var perf_recovery_btn: Button = get_node_or_null("Panel/VBox/Tabs/Performance Monitor/PerfToolbar/PerfRecoveryBtn")
@onready var perf_report_btn: Button = get_node_or_null("Panel/VBox/Tabs/Performance Monitor/PerfToolbar/PerfReportBtn")
@onready var perf_clear_btn: Button = get_node_or_null("Panel/VBox/Tabs/Performance Monitor/PerfToolbar/PerfClearBtn")

# Performance Card Labels
@onready var session_id_lbl: Label = get_node_or_null("Panel/VBox/Tabs/Performance Monitor/PerfScroll/PerfContent/Grid/SessionPanel/VBox/SessionIdLabel")
@onready var session_duration_lbl: Label = get_node_or_null("Panel/VBox/Tabs/Performance Monitor/PerfScroll/PerfContent/Grid/SessionPanel/VBox/SessionDurationLabel")
@onready var session_status_lbl: Label = get_node_or_null("Panel/VBox/Tabs/Performance Monitor/PerfScroll/PerfContent/Grid/SessionPanel/VBox/SessionStatusLabel")
@onready var session_scene_lbl: Label = get_node_or_null("Panel/VBox/Tabs/Performance Monitor/PerfScroll/PerfContent/Grid/SessionPanel/VBox/SessionSceneLabel")

@onready var fps_current_lbl: Label = get_node_or_null("Panel/VBox/Tabs/Performance Monitor/PerfScroll/PerfContent/Grid/FpsPanel/VBox/FpsCurrentLabel")
@onready var fps_average_lbl: Label = get_node_or_null("Panel/VBox/Tabs/Performance Monitor/PerfScroll/PerfContent/Grid/FpsPanel/VBox/FpsAverageLabel")
@onready var fps_min_max_lbl: Label = get_node_or_null("Panel/VBox/Tabs/Performance Monitor/PerfScroll/PerfContent/Grid/FpsPanel/VBox/FpsMinMaxLabel")
@onready var fps_low_lbl: Label = get_node_or_null("Panel/VBox/Tabs/Performance Monitor/PerfScroll/PerfContent/Grid/FpsPanel/VBox/FpsLowLabel")

@onready var mem_current_lbl: Label = get_node_or_null("Panel/VBox/Tabs/Performance Monitor/PerfScroll/PerfContent/Grid/MemoryPanel/VBox/MemoryCurrentLabel")
@onready var mem_peak_lbl: Label = get_node_or_null("Panel/VBox/Tabs/Performance Monitor/PerfScroll/PerfContent/Grid/MemoryPanel/VBox/MemoryPeakLabel")
@onready var mem_status_lbl: Label = get_node_or_null("Panel/VBox/Tabs/Performance Monitor/PerfScroll/PerfContent/Grid/MemoryPanel/VBox/MemoryStatusLabel")
@onready var mem_note_lbl: Label = get_node_or_null("Panel/VBox/Tabs/Performance Monitor/PerfScroll/PerfContent/Grid/MemoryPanel/VBox/MemoryNoteLabel")

@onready var load_total_lbl: Label = get_node_or_null("Panel/VBox/Tabs/Performance Monitor/PerfScroll/PerfContent/Grid/LoadingPanel/VBox/LoadingTotalLabel")
@onready var load_average_lbl: Label = get_node_or_null("Panel/VBox/Tabs/Performance Monitor/PerfScroll/PerfContent/Grid/LoadingPanel/VBox/LoadingAverageLabel")
@onready var load_min_max_lbl: Label = get_node_or_null("Panel/VBox/Tabs/Performance Monitor/PerfScroll/PerfContent/Grid/LoadingPanel/VBox/LoadingMinMaxLabel")
@onready var load_fail_lbl: Label = get_node_or_null("Panel/VBox/Tabs/Performance Monitor/PerfScroll/PerfContent/Grid/LoadingPanel/VBox/LoadingFailLabel")

@onready var api_requests_lbl: Label = get_node_or_null("Panel/VBox/Tabs/Performance Monitor/PerfScroll/PerfContent/Grid/ApiPanel/VBox/ApiRequestsLabel")
@onready var api_average_lbl: Label = get_node_or_null("Panel/VBox/Tabs/Performance Monitor/PerfScroll/PerfContent/Grid/ApiPanel/VBox/ApiAverageLabel")
@onready var api_min_max_lbl: Label = get_node_or_null("Panel/VBox/Tabs/Performance Monitor/PerfScroll/PerfContent/Grid/ApiPanel/VBox/ApiMinMaxLabel")
@onready var api_fail_lbl: Label = get_node_or_null("Panel/VBox/Tabs/Performance Monitor/PerfScroll/PerfContent/Grid/ApiPanel/VBox/ApiFailLabel")

@onready var error_total_lbl: Label = get_node_or_null("Panel/VBox/Tabs/Performance Monitor/PerfScroll/PerfContent/Grid/ErrorPanel/VBox/ErrorTotalLabel")
@onready var error_ops_lbl: Label = get_node_or_null("Panel/VBox/Tabs/Performance Monitor/PerfScroll/PerfContent/Grid/ErrorPanel/VBox/ErrorOpsLabel")
@onready var error_rate_lbl: Label = get_node_or_null("Panel/VBox/Tabs/Performance Monitor/PerfScroll/PerfContent/Grid/ErrorPanel/VBox/ErrorRateLabel")
@onready var error_status_lbl: Label = get_node_or_null("Panel/VBox/Tabs/Performance Monitor/PerfScroll/PerfContent/Grid/ErrorPanel/VBox/ErrorStatusLabel")

@onready var stability_state_lbl: Label = get_node_or_null("Panel/VBox/Tabs/Performance Monitor/PerfScroll/PerfContent/Grid/StabilityPanel/VBox/StabilityStateLabel")
@onready var stability_interr_lbl: Label = get_node_or_null("Panel/VBox/Tabs/Performance Monitor/PerfScroll/PerfContent/Grid/StabilityPanel/VBox/StabilityInterrLabel")
@onready var stability_unrec_lbl: Label = get_node_or_null("Panel/VBox/Tabs/Performance Monitor/PerfScroll/PerfContent/Grid/StabilityPanel/VBox/StabilityUnrecLabel")
@onready var stability_trans_lbl: Label = get_node_or_null("Panel/VBox/Tabs/Performance Monitor/PerfScroll/PerfContent/Grid/StabilityPanel/VBox/StabilityTransLabel")

@onready var rec_attempts_lbl: Label = get_node_or_null("Panel/VBox/Tabs/Performance Monitor/PerfScroll/PerfContent/Grid/RecoveryPanel/VBox/RecoveryAttemptsLabel")
@onready var rec_success_lbl: Label = get_node_or_null("Panel/VBox/Tabs/Performance Monitor/PerfScroll/PerfContent/Grid/RecoveryPanel/VBox/RecoverySuccessLabel")
@onready var rec_avg_lbl: Label = get_node_or_null("Panel/VBox/Tabs/Performance Monitor/PerfScroll/PerfContent/Grid/RecoveryPanel/VBox/RecoveryAvgLabel")
@onready var rec_max_lbl: Label = get_node_or_null("Panel/VBox/Tabs/Performance Monitor/PerfScroll/PerfContent/Grid/RecoveryPanel/VBox/RecoveryMaxLabel")

# Command bar
@onready var command_input: LineEdit = get_node_or_null("Panel/VBox/CommandBar/CommandInput")
@onready var execute_btn: Button = get_node_or_null("Panel/VBox/CommandBar/ExecuteBtn")

func _ready() -> void:
	layer = 128
	panel.visible = false
	
	close_btn.pressed.connect(func(): panel.visible = false)
	clear_btn.pressed.connect(_on_clear_pressed)
	copy_btn.pressed.connect(_on_copy_pressed)
	reset_bkt_btn.pressed.connect(_on_reset_bkt_pressed)
	
	if finish_call_btn:
		finish_call_btn.pressed.connect(func(): execute_command("finish_call"))
	if end_shift_btn:
		end_shift_btn.pressed.connect(func(): execute_command("end_shift"))
	if execute_btn and command_input:
		execute_btn.pressed.connect(func(): _on_command_submitted(command_input.text))
	if command_input:
		command_input.text_submitted.connect(_on_command_submitted)

	# Connect Performance Toolbar buttons
	if perf_start_btn:
		perf_start_btn.pressed.connect(func(): execute_command("performance_start"))
	if perf_stop_btn:
		perf_stop_btn.pressed.connect(func(): execute_command("performance_stop"))
	if perf_recovery_btn:
		perf_recovery_btn.pressed.connect(func(): execute_command("test_recovery"))
	if perf_report_btn:
		perf_report_btn.pressed.connect(func(): execute_command("performance_report"))
	if perf_clear_btn:
		perf_clear_btn.pressed.connect(func(): execute_command("performance_clear"))

	# Connect to SafeScapePerformanceManager signals if available
	var perf_mgr = SafeScapePerformanceManager.get_instance()
	if perf_mgr:
		perf_mgr.performance_updated.connect(_refresh_performance_ui)

func _process(_delta: float) -> void:
	# Keep performance UI updated while visible
	if panel.visible and tabs and tabs.current_tab == 1:
		_refresh_performance_ui()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		# Toggle with ~ (Tilde / Backquote) or F12 or Ctrl+Shift+D
		if event.keycode == KEY_QUOTELEFT or event.keycode == KEY_F12 or (event.keycode == KEY_D and event.ctrl_pressed and event.shift_pressed):
			toggle_console()
			get_viewport().set_input_as_handled()

func toggle_console() -> void:
	panel.visible = not panel.visible
	if panel.visible:
		_refresh_performance_ui()
		if command_input:
			command_input.call_deferred("grab_focus")

func append_log_entry(json_line: String, _record_dict: Dictionary) -> void:
	if log_display:
		log_display.text += json_line + "\n\n"
		log_display.set_caret_line(log_display.get_line_count() - 1)

func append_perf_log_entry(json_line: String, _record_dict: Dictionary) -> void:
	if perf_log_display:
		perf_log_display.text += json_line + "\n\n"
		perf_log_display.set_caret_line(perf_log_display.get_line_count() - 1)

func _on_copy_pressed() -> void:
	if tabs and tabs.current_tab == 1 and perf_log_display:
		DisplayServer.clipboard_set(perf_log_display.text)
	elif log_display:
		DisplayServer.clipboard_set(log_display.text)

func _on_clear_pressed() -> void:
	if tabs and tabs.current_tab == 1 and perf_log_display:
		perf_log_display.text = ""
	elif log_display:
		log_display.text = ""
		
func _on_reset_bkt_pressed() -> void:
	var state = get_node_or_null("/root/GameState")
	if state and state.has_method("reset_bkt_state"):
		state.call("reset_bkt_state")
		_append_dev_output(">>> [EVAL CONSOLE] BKT Learner State Reset to P(L0)=0.40 <<<\n")

func _on_command_submitted(new_text: String) -> void:
	if command_input:
		command_input.text = ""
	execute_command(new_text)

func execute_command(cmd_text: String) -> void:
	var cmd = cmd_text.strip_edges().to_lower()
	if cmd == "":
		return
		
	match cmd:
		"finish_call":
			_handle_finish_call()
		"end_shift":
			_handle_end_shift()
		"reset_bkt":
			_on_reset_bkt_pressed()
		"clear":
			_on_clear_pressed()
		"performance_start":
			_handle_performance_start()
		"performance_stop":
			_handle_performance_stop()
		"performance_clear":
			_handle_performance_clear()
		"performance_show":
			_handle_performance_show()
		"performance_report":
			_handle_performance_report()
		"test_recovery":
			_handle_test_recovery()
		"help":
			_show_help()
		_:
			_append_dev_output("Unknown command '%s'. Available commands: finish_call, end_shift, reset_bkt, performance_start, performance_stop, performance_clear, performance_show, performance_report, test_recovery, clear, help\n" % cmd)

# ── Command Handlers ────────────────────────────────────────────────────────────

func _handle_finish_call() -> void:
	var scene = get_tree().current_scene
	if scene and scene.has_method("dev_finish_call"):
		var record = scene.call("dev_finish_call")
		if typeof(record) == TYPE_DICTIONARY:
			var json_line = JSON.stringify(record)
			print("[DEV_CONSOLE] " + json_line)
			_append_dev_output(json_line + "\n\n")
			_send_web_dev_log(json_line)
		else:
			_append_dev_output("finish_call executed (no record returned).\n")
	else:
		var err = {
			"event": "dev_finish_call",
			"command": "finish_call",
			"error": "Command only available while in active RouteScene gameplay",
			"success": false
		}
		var err_line = JSON.stringify(err)
		print("[DEV_CONSOLE] " + err_line)
		_append_dev_output(err_line + "\n\n")

func _handle_end_shift() -> void:
	var scene = get_tree().current_scene
	if scene and scene.has_method("dev_end_shift"):
		var record = scene.call("dev_end_shift")
		if typeof(record) == TYPE_DICTIONARY:
			var json_line = JSON.stringify(record)
			print("[DEV_CONSOLE] " + json_line)
			_append_dev_output(json_line + "\n\n")
			_send_web_dev_log(json_line)
		else:
			_append_dev_output("end_shift executed (no record returned).\n")
	else:
		var err = {
			"event": "dev_end_shift",
			"command": "end_shift",
			"error": "Command only available while in RouteScene",
			"success": false
		}
		var err_line = JSON.stringify(err)
		print("[DEV_CONSOLE] " + err_line)
		_append_dev_output(err_line + "\n\n")

func _handle_performance_start() -> void:
	var perf_mgr = SafeScapePerformanceManager.get_instance()
	if perf_mgr:
		var rec = perf_mgr.start_session()
		var json_line = JSON.stringify(rec)
		_append_dev_output(">>> [PERF SESSION STARTED] ID: %s <<<\n%s\n\n" % [rec.get("session_id", ""), json_line])
		_refresh_performance_ui()
	else:
		_append_dev_output("Error: SafeScapePerformanceManager not found in scene tree.\n")

func _handle_performance_stop() -> void:
	var perf_mgr = SafeScapePerformanceManager.get_instance()
	if perf_mgr:
		var rec = perf_mgr.stop_session()
		var json_line = JSON.stringify(rec)
		_append_dev_output(">>> [PERF SESSION STOPPED] <<<\n%s\n\n" % json_line)
		_refresh_performance_ui()
	else:
		_append_dev_output("Error: SafeScapePerformanceManager not found in scene tree.\n")

func _handle_performance_clear() -> void:
	var perf_mgr = SafeScapePerformanceManager.get_instance()
	if perf_mgr:
		perf_mgr.clear_metrics()
		if perf_log_display:
			perf_log_display.text = ""
		_append_dev_output(">>> [PERF METRICS CLEARED] <<<\n")
		_refresh_performance_ui()
	else:
		_append_dev_output("Error: SafeScapePerformanceManager not found in scene tree.\n")

func _handle_performance_show() -> void:
	panel.visible = true
	if tabs:
		tabs.current_tab = 1
	_refresh_performance_ui()
	if command_input:
		command_input.call_deferred("grab_focus")

func _handle_performance_report() -> void:
	var perf_mgr = SafeScapePerformanceManager.get_instance()
	if perf_mgr:
		var report_text = perf_mgr.get_report_text()
		_append_dev_output(report_text + "\n")
		# Also log summary to evaluation logger
		var summary = perf_mgr.get_summary()
		SafeScapeEvaluationLogger.log_performance_event(summary)
	else:
		_append_dev_output("Error: SafeScapePerformanceManager not found in scene tree.\n")

func _handle_test_recovery() -> void:
	var perf_mgr = SafeScapePerformanceManager.get_instance()
	if perf_mgr:
		_append_dev_output(">>> [EXECUTING CONTROLLED RECOVERY TEST] <<<\n")
		var rec = perf_mgr.run_recovery_test()
		var json_line = JSON.stringify(rec)
		_append_dev_output(json_line + "\n\n")
		_refresh_performance_ui()
	else:
		_append_dev_output("Error: SafeScapePerformanceManager not found in scene tree.\n")

func _show_help() -> void:
	var help_text = (
		"======================================================================\n" +
		"  SAFESCAPE 2.0 DEVELOPER & EVALUATION COMMANDS                       \n" +
		"======================================================================\n" +
		"  finish_call       : Immediately complete current call safely.\n" +
		"  end_shift         : Complete current shift/day and advance to next.\n" +
		"  reset_bkt         : Reset BKT mastery to initial prior (0.40).\n" +
		"  performance_start : Start a new performance test session.\n" +
		"  performance_stop  : Stop active performance test session & log summary.\n" +
		"  performance_clear : Clear all performance and stability measurements.\n" +
		"  performance_show  : Open console and show Performance Monitor dashboard.\n" +
		"  performance_report: Generate and display full performance report.\n" +
		"  test_recovery     : Trigger controlled, safe recovery behavior test.\n" +
		"  clear             : Clear console logs.\n" +
		"  help              : Show this list of commands.\n" +
		"======================================================================\n\n"
	)
	_append_dev_output(help_text)

func _append_dev_output(text: String) -> void:
	if log_display:
		log_display.text += text
		log_display.set_caret_line(log_display.get_line_count() - 1)
	if perf_log_display and tabs and tabs.current_tab == 1:
		perf_log_display.text += text
		perf_log_display.set_caret_line(perf_log_display.get_line_count() - 1)

func _send_web_dev_log(json_str: String) -> void:
	if OS.has_feature("web"):
		if Engine.has_singleton("JavaScriptBridge"):
			var js = Engine.get_singleton("JavaScriptBridge")
			if js != null:
				var escaped = json_str.replace("\\", "\\\\").replace("'", "\\'").replace("\n", "")
				js.eval("try { console.log('SAFESCAPE_DEV:', '%s'); } catch(e) {}" % escaped)

# ── Performance Dashboard Refresh ───────────────────────────────────────────────

func _refresh_performance_ui() -> void:
	var perf_mgr = SafeScapePerformanceManager.get_instance()
	if not perf_mgr:
		return

	# Session Panel
	if session_id_lbl:
		session_id_lbl.text = "ID: %s" % (perf_mgr.session_id if perf_mgr.session_id != "" else "idle")
	if session_duration_lbl:
		session_duration_lbl.text = "Duration: %.1fs" % perf_mgr.get_session_duration_seconds()
	if session_status_lbl:
		session_status_lbl.text = "Status: %s" % ("ACTIVE" if perf_mgr.session_active else perf_mgr.session_last_state.to_upper())
	if session_scene_lbl:
		session_scene_lbl.text = "Scene: %s" % perf_mgr._get_current_scene_path().get_file()

	# FPS Panel
	if fps_current_lbl:
		fps_current_lbl.text = "Current: %.1f FPS" % perf_mgr.fps_current
	if fps_average_lbl:
		fps_average_lbl.text = "Average: %.1f FPS (%d samples)" % [perf_mgr.get_average_fps(), perf_mgr.fps_sample_count]
	if fps_min_max_lbl:
		var min_f = perf_mgr.fps_min if perf_mgr.fps_min >= 0.0 else 0.0
		fps_min_max_lbl.text = "Min / Max: %.1f / %.1f FPS" % [min_f, perf_mgr.fps_max]
	if fps_low_lbl:
		fps_low_lbl.text = "Low (<30): %d (%.1f%%)" % [perf_mgr.fps_low_sample_count, perf_mgr.get_low_fps_percentage()]

	# Memory Panel
	if mem_current_lbl:
		mem_current_lbl.text = "Current: %.2f MB" % perf_mgr.memory_current_mb if perf_mgr.memory_supported else "Current: N/A"
	if mem_peak_lbl:
		mem_peak_lbl.text = "Peak: %.2f MB" % perf_mgr.memory_peak_mb if perf_mgr.memory_supported else "Peak: N/A"
	if mem_status_lbl:
		mem_status_lbl.text = "Supported: %s" % ("Yes" if perf_mgr.memory_supported else "No (Platform)")
	if mem_note_lbl:
		mem_note_lbl.text = "Note: Active" if perf_mgr.memory_supported else "Note: %s" % perf_mgr.memory_unavailable_reason

	# Loading Panel
	if load_total_lbl:
		load_total_lbl.text = "Total Loads: %d (ok: %d)" % [perf_mgr.loading_total_count, perf_mgr.loading_success_count]
	if load_average_lbl:
		load_average_lbl.text = "Average: %.2f ms" % perf_mgr.get_average_loading_ms()
	if load_min_max_lbl:
		var min_l = perf_mgr.loading_min_ms if perf_mgr.loading_min_ms >= 0.0 else 0.0
		load_min_max_lbl.text = "Min / Max: %.2f / %.2f ms" % [min_l, perf_mgr.loading_max_ms]
	if load_fail_lbl:
		load_fail_lbl.text = "Failures: %d" % perf_mgr.loading_failed_count

	# API Panel
	if api_requests_lbl:
		if perf_mgr.api_total_requests == 0:
			api_requests_lbl.text = "Requests: 0 (N/A in mode)"
		else:
			api_requests_lbl.text = "Requests: %d (ok: %d)" % [perf_mgr.api_total_requests, perf_mgr.api_successful_requests]
	if api_average_lbl:
		api_average_lbl.text = "Average: %s ms" % str(perf_mgr.get_average_api_response_ms())
	if api_min_max_lbl:
		var min_a = "%.2f" % perf_mgr.api_min_time_ms if perf_mgr.api_min_time_ms >= 0.0 else "N/A"
		var max_a = "%.2f" % perf_mgr.api_max_time_ms if perf_mgr.api_max_time_ms > 0.0 else "N/A"
		api_min_max_lbl.text = "Min / Max: %s / %s ms" % [min_a, max_a]
	if api_fail_lbl:
		api_fail_lbl.text = "Failures / Timeouts: %d / %d" % [perf_mgr.api_failed_requests, perf_mgr.api_timeout_count]

	# Error Panel
	if error_total_lbl:
		error_total_lbl.text = "Software Errors: %d" % perf_mgr.error_total_count
	if error_ops_lbl:
		error_ops_lbl.text = "Total Operations: %d" % perf_mgr.get_total_relevant_operations()
	if error_rate_lbl:
		error_rate_lbl.text = "Error Rate: %.2f%%" % perf_mgr.get_error_rate()
	if error_status_lbl:
		error_status_lbl.text = "Gameplay Mistakes: Excluded"

	# Stability Panel
	if stability_state_lbl:
		stability_state_lbl.text = "State: %s" % ("Operational" if perf_mgr.stability_unrecovered_failures == 0 else "Degraded")
	if stability_interr_lbl:
		stability_interr_lbl.text = "Interruptions: %d" % perf_mgr.stability_interruptions
	if stability_unrec_lbl:
		stability_unrec_lbl.text = "Unrecovered Fails: %d" % perf_mgr.stability_unrecovered_failures
	if stability_trans_lbl:
		stability_trans_lbl.text = "Transitions: %d ok / %d fail" % [perf_mgr.stability_successful_scene_transitions, perf_mgr.stability_failed_scene_transitions]

	# Recovery Panel
	if rec_attempts_lbl:
		rec_attempts_lbl.text = "Attempts: %d" % perf_mgr.recovery_attempts
	if rec_success_lbl:
		rec_success_lbl.text = "Success / Fail: %d / %d" % [perf_mgr.recovery_success_count, perf_mgr.recovery_failed_count]
	if rec_avg_lbl:
		rec_avg_lbl.text = "Average: %.2f ms" % perf_mgr.get_average_recovery_time_ms()
	if rec_max_lbl:
		rec_max_lbl.text = "Max: %.2f ms" % perf_mgr.recovery_max_time_ms
