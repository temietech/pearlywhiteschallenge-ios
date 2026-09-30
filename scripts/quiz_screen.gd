# scripts/quiz_screen.gd
extends Control

signal quiz_completed

const BASELINE_QUESTIONS = [
	{
		"q": "How many minutes should you brush your teeth each time?",
		"options": ["2 minutes", "1 minute", "5 minutes", "30 seconds"],
		"concept": "Brushing Duration",
		"tip": "Brush for 2 minutes, twice a day — that's the sweet spot!"
	},
	{
		"q": "What is tooth enamel and why is it important to protect?",
		"options": ["Hard outer shield protecting teeth", "Soft center inside a tooth", "A type of bubble gum"],
		"concept": "Tooth Enamel",
		"tip": "Your tooth enamel is the hardest thing in your body, but it can never grow back!"
	},
	{
		"q": "Why is it important to floss between your teeth?",
		"options": ["Cleans spots the brush misses", "Makes teeth shiny blue", "Replaces toothbrushing"],
		"concept": "Flossing",
		"tip": "Floss reaches 40% of the tooth surface a brush can't!"
	},
	{
		"q": "How does eating lots of sugar affect our teeth?",
		"options": ["Feeds cavity-causing bacteria", "Makes teeth stronger", "Has no effect at all"],
		"concept": "Sugar Impact",
		"tip": "Sugar feeds cavity-causing bacteria — rinse with water after treats!"
	},
	{
		"q": "How often should you replace your toothbrush with a new one?",
		"options": ["Every 3 months", "Once every year", "Every single week", "Never"],
		"concept": "Toothbrush Replacement",
		"tip": "Change your toothbrush every 3 months for the best clean!"
	},
	{
		"q": "How does chewing sugar-free gum help fight cavities?",
		"options": ["Boosts saliva to wash away acid", "Replaces brushing entirely", "Turns your teeth bright blue"],
		"concept": "Sugar-Free Gum",
		"tip": "Chewing sugar-free gum makes saliva that washes harmful acids away!"
	},
	{
		"q": "How common are tooth cavities in children compared to asthma?",
		"options": ["5x more common than asthma", "Very rare — almost nobody gets them", "Asthma is 100x more common"],
		"concept": "Childhood Cavities",
		"tip": "Cavities in kids are 5x more common than asthma — daily brushing keeps them away!"
	}
]

var current_question_idx: int = 0
var correct_answers: int = 0
var questions: Array = []
var results: Array = []
var week_num: int = 1
var is_baseline: bool = false
var baseline_answers: Array = []

var bg: TextureRect
var back_btn: TextureButton
var stats_vbox: VBoxContainer
var coins_label: Label
var points_label: Label
var title_rect: TextureRect
var title_lbl: Label
var dots_hbox: HBoxContainer

static var _cached_quiz_title_tex: Texture2D = null

func _load_questions():
	var p = GameState.get_active_profile()
	var cur_node = int(p.get("currentNode", 0))
	var day = GameState.day_for_node(cur_node)
	
	if day == 0 or cur_node == 0:
		is_baseline = true
		questions = BASELINE_QUESTIONS
	else:
		is_baseline = false
		week_num = clamp(int(ceil(float(day) / 7.0)), 1, 4)
		var bank: Array = []
		if week_num - 1 < GameState.QUIZ_BANKS.size():
			bank = GameState.QUIZ_BANKS[week_num - 1]
		else:
			bank = GameState.QUIZ_BANKS[0]
			
		# Separate open preview questions to come FIRST, and True/False recap questions to come SECOND
		var open_qs: Array = []
		var tf_qs: Array = []
		for q in bank:
			if q.get("section", "") == "PREVIEW" or q.get("type", "") == "open":
				open_qs.append(q)
			else:
				tf_qs.append(q)
		questions = open_qs + tf_qs
			
	current_question_idx = 0
	correct_answers = 0
	results.clear()
	baseline_answers.clear()
	for i in range(questions.size()):
		results.append(null)

static func _ensure_quiz_title_texture() -> Texture2D:
	if _cached_quiz_title_tex and is_instance_valid(_cached_quiz_title_tex):
		return _cached_quiz_title_tex
		
	var direct_tex = UIHelper.load_texture_safe("res://assets/images/titles/weeklyquiz_title.png")
	if not direct_tex:
		direct_tex = UIHelper.load_texture_safe("res://assets/images/titles/weeklyquiz_title.png")
	if direct_tex:
		_cached_quiz_title_tex = direct_tex
		return _cached_quiz_title_tex
		
	var path = "res://assets/images/quiz2/weekly_quiz_title.png"
	var global_path = ProjectSettings.globalize_path(path)
	
	if FileAccess.file_exists(global_path):
		var img = Image.load_from_file(global_path)
		if img and not img.is_empty():
			_cached_quiz_title_tex = ImageTexture.create_from_image(img)
			return _cached_quiz_title_tex
			
	var screen_tex = UIHelper.load_texture_safe("res://screens/45-quiz-feedback.png")
	if not screen_tex:
		screen_tex = UIHelper.load_texture_safe("res://screens/13-quiz.png")
		
	if screen_tex:
		var full_img = screen_tex.get_image()
		if full_img and not full_img.is_empty():
			var iw = full_img.get_width()
			var ih = full_img.get_height()
			
			var crop_x = int(iw * 0.33)
			var crop_y = int(ih * 0.013)
			var crop_w = int(iw * 0.34)
			var crop_h = int(ih * 0.063)
			
			var cropped = Image.create(crop_w, crop_h, false, Image.FORMAT_RGBA8)
			cropped.blit_rect(full_img, Rect2i(crop_x, crop_y, crop_w, crop_h), Vector2i.ZERO)
			
			# Flood-fill transparency from corners for the blue background
			var bg_col = cropped.get_pixel(0, 0)
			var w = cropped.get_width()
			var h = cropped.get_height()
			var visited = PackedByteArray()
			visited.resize(w * h)
			visited.fill(0)
			
			var queue: Array[Vector2i] = [
				Vector2i(0, 0), Vector2i(w - 1, 0),
				Vector2i(0, h - 1), Vector2i(w - 1, h - 1),
				Vector2i(int(w * 0.5), 0), Vector2i(int(w * 0.5), h - 1)
			]
			
			for qp in queue:
				visited[qp.y * w + qp.x] = 1
				
			while not queue.is_empty():
				var p = queue.pop_front()
				var col = cropped.get_pixel(p.x, p.y)
				
				var dr = abs(col.r - bg_col.r)
				var dg = abs(col.g - bg_col.g)
				var db = abs(col.b - bg_col.b)
				var is_bg = (dr < 0.20 and dg < 0.20 and db < 0.20) or (col.b > 0.85 and col.r > 0.65 and col.g > 0.80)
				
				if is_bg:
					cropped.set_pixel(p.x, p.y, Color(0, 0, 0, 0))
					var n_offsets = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
					for off in n_offsets:
						var nx = p.x + off.x
						var ny = p.y + off.y
						if nx >= 0 and nx < w and ny >= 0 and ny < h:
							var idx = ny * w + nx
							if visited[idx] == 0:
								visited[idx] = 1
								queue.append(Vector2i(nx, ny))
								
			cropped.save_png(global_path)
			_cached_quiz_title_tex = ImageTexture.create_from_image(cropped)
			return _cached_quiz_title_tex
			
	return null

var card: Panel
var tab_pill: Panel
var question_tab_label: Label

var question_container: Control
var question_text: Label
var tf_hbox: HBoxContainer
var true_btn: TextureButton
var false_btn: TextureButton

# Open-ended baseline question UI
var open_input_container: VBoxContainer
var text_row: BoxContainer
var open_line_edit: LineEdit
var open_options_vbox: VBoxContainer
var open_submit_btn: Button

var feedback_container: Control
var feedback_header_lbl: RichTextLabel
var crown_img: TextureRect
var tip_panel: Panel
var tip_lbl: Label
var next_btn: Button
var confirm_back_modal: Control

func _ready():
	set_anchors_preset(Control.PRESET_FULL_RECT)
	anchor_right = 1.0
	anchor_bottom = 1.0
	offset_right = 0
	offset_bottom = 0
	_load_questions()
	_build_ui()
	_relayout()
	_show_question()
	if is_baseline:
		call_deferred("_show_story_intro")

func _show_story_intro():
	UIHelper.show_node0_story_intro_modal(self)

func _notification(what: int):
	if what == NOTIFICATION_RESIZED:
		if is_node_ready():
			_relayout()

func _build_ui():
	# 1. Background (Clean procedural sky gradient)
	bg = TextureRect.new()
	UIHelper.setup_fullscreen_bg(bg)
	bg.texture = UIHelper.create_sky_gradient_texture()
	add_child(bg)
	
	# 2. Top Back Button
	back_btn = UIHelper.create_image_button("res://assets/images/misc/blue_back_button.png", Vector2(86, 36))
	if not back_btn.texture_normal:
		back_btn = UIHelper.create_image_button("res://assets/images/shop/blue_back_button.png", Vector2(86, 36))
	back_btn.z_index = 20
	back_btn.pressed.connect(_on_back_pressed)
	add_child(back_btn)
	
	# 3. Top Right Stats (Coins and Points pills)
	stats_vbox = VBoxContainer.new()
	stats_vbox.size = Vector2(100, 68)
	stats_vbox.add_theme_constant_override("separation", 6)
	stats_vbox.z_index = 20
	add_child(stats_vbox)
	
	var p = GameState.get_active_profile()
	
	# Coin pill
	var coin_pill = PanelContainer.new()
	coin_pill.custom_minimum_size = Vector2(100, 30)
	var cp_style = StyleBoxFlat.new()
	cp_style.bg_color = Color(0.12, 0.35, 0.65, 0.90)
	cp_style.set_corner_radius_all(15)
	cp_style.border_width_left = 2
	cp_style.border_width_right = 2
	cp_style.border_width_top = 2
	cp_style.border_width_bottom = 2
	cp_style.border_color = Color.WHITE
	coin_pill.add_theme_stylebox_override("panel", cp_style)
	
	var coin_hbox = HBoxContainer.new()
	coin_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	coin_hbox.add_theme_constant_override("separation", 6)
	coin_pill.add_child(coin_hbox)
	
	var coin_icon = TextureRect.new()
	coin_icon.custom_minimum_size = Vector2(20, 20)
	coin_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	coin_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	coin_icon.texture = UIHelper.load_texture_safe("res://assets/images/congratulations/gold_tooth_coin.png")
	if not coin_icon.texture:
		coin_icon.texture = UIHelper.load_texture_safe("res://assets/images/misc/gold_tooth_coin.png")
	coin_hbox.add_child(coin_icon)
	
	coins_label = Label.new()
	coins_label.text = str(int(round(float(p.get("coins", 0)))))
	UIHelper.apply_bubbly_label(coins_label, 13, Color.WHITE, true)
	coin_hbox.add_child(coins_label)
	stats_vbox.add_child(coin_pill)
	
	# Points pill
	var pt_pill = PanelContainer.new()
	pt_pill.custom_minimum_size = Vector2(100, 30)
	var pp_style = StyleBoxFlat.new()
	pp_style.bg_color = Color(0.50, 0.22, 0.78, 0.90)
	pp_style.set_corner_radius_all(15)
	pp_style.border_width_left = 2
	pp_style.border_width_right = 2
	pp_style.border_width_top = 2
	pp_style.border_width_bottom = 2
	pp_style.border_color = Color.WHITE
	pt_pill.add_theme_stylebox_override("panel", pp_style)
	
	var pt_hbox = HBoxContainer.new()
	pt_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	pt_hbox.add_theme_constant_override("separation", 6)
	pt_pill.add_child(pt_hbox)
	
	var pt_icon = TextureRect.new()
	pt_icon.custom_minimum_size = Vector2(20, 20)
	pt_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pt_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pt_icon.texture = UIHelper.load_texture_safe("res://assets/images/brushing/purple_star_points.png")
	if not pt_icon.texture:
		pt_icon.texture = UIHelper.load_texture_safe("res://assets/images/shop/purple_star_points.png")
	pt_hbox.add_child(pt_icon)
	
	points_label = Label.new()
	points_label.text = str(int(round(float(p.get("points", 0)))))
	UIHelper.apply_bubbly_label(points_label, 13, Color.WHITE, true)
	pt_hbox.add_child(points_label)
	stats_vbox.add_child(pt_pill)
	
	# 4. Title: Title "WEEKLY QUIZ" or "DISCOVERY QUIZ"
	var is_final_quiz: bool = (not is_baseline) and week_num >= 4
	if not is_baseline and not is_final_quiz:
		var quiz_tex = _ensure_quiz_title_texture()
		if quiz_tex:
			title_rect = TextureRect.new()
			title_rect.texture = quiz_tex
			title_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			title_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			add_child(title_rect)
	
	if not title_rect:
		title_lbl = Label.new()
		title_lbl.text = "DISCOVERY QUIZ" if is_baseline else ("FINAL QUIZ" if is_final_quiz else "WEEKLY QUIZ")
		title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		UIHelper.apply_bubbly_label(title_lbl, 32, Color.WHITE, true)
		title_lbl.add_theme_color_override("font_shadow_color", Color(0.10, 0.32, 0.62, 0.90))
		title_lbl.add_theme_constant_override("shadow_offset_x", 0)
		title_lbl.add_theme_constant_override("shadow_offset_y", 4)
		title_lbl.add_theme_color_override("font_outline_color", Color(0.12, 0.40, 0.72))
		title_lbl.add_theme_constant_override("outline_size", 6)
		add_child(title_lbl)
	
	# 5. Progress Capsules (7 capsules tracking answers)
	dots_hbox = HBoxContainer.new()
	dots_hbox.set_anchors_preset(Control.PRESET_TOP_WIDE)
	dots_hbox.anchor_left = 0.0
	dots_hbox.anchor_right = 1.0
	dots_hbox.offset_left = 0.0
	dots_hbox.offset_right = 0.0
	dots_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	dots_hbox.add_theme_constant_override("separation", 8)
	dots_hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dots_hbox)
	
	# 6. Main White Rounded Card
	card = Panel.new()
	var card_style = StyleBoxFlat.new()
	card_style.bg_color = Color(1.0, 1.0, 1.0, 0.98)
	card_style.set_corner_radius_all(34)
	card_style.border_width_left = 4
	card_style.border_width_right = 4
	card_style.border_width_top = 4
	card_style.border_width_bottom = 4
	card_style.border_color = Color.WHITE
	card_style.shadow_color = Color(0.08, 0.28, 0.52, 0.22)
	card_style.shadow_size = 18
	card_style.shadow_offset = Vector2(0, 8)
	card.add_theme_stylebox_override("panel", card_style)
	add_child(card)
	
	# 7. Blue "QUESTION X" Pill Badge (pinned over top edge of card)
	tab_pill = Panel.new()
	var tp_style = StyleBoxFlat.new()
	tp_style.bg_color = Color(0.24, 0.62, 0.94)
	tp_style.set_corner_radius_all(20)
	tp_style.border_width_left = 3
	tp_style.border_width_right = 3
	tp_style.border_width_top = 3
	tp_style.border_width_bottom = 3
	tp_style.border_color = Color.WHITE
	tp_style.shadow_color = Color(0.08, 0.28, 0.52, 0.20)
	tp_style.shadow_size = 6
	tp_style.shadow_offset = Vector2(0, 3)
	tab_pill.add_theme_stylebox_override("panel", tp_style)
	tab_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(tab_pill)
	
	question_tab_label = Label.new()
	question_tab_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	question_tab_label.text = "QUESTION 1"
	question_tab_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	question_tab_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UIHelper.apply_bubbly_label(question_tab_label, 15, Color.WHITE, true)
	tab_pill.add_child(question_tab_label)
	
	# 8. Question View Container
	question_container = Control.new()
	question_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	card.add_child(question_container)
	
	question_text = Label.new()
	question_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	question_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	question_text.autowrap_mode = TextServer.AUTOWRAP_WORD
	question_text.add_theme_constant_override("line_spacing", 6)
	UIHelper.apply_bubbly_label(question_text, 22, Color(0.12, 0.35, 0.60), true)
	question_container.add_child(question_text)
	
	# True/False Buttons Row
	tf_hbox = HBoxContainer.new()
	tf_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	tf_hbox.add_theme_constant_override("separation", 14)
	question_container.add_child(tf_hbox)
	
	var true_tex = UIHelper.load_texture_safe("res://assets/images/quizpage1/true_button.png")
	if not true_tex:
		true_tex = UIHelper.load_texture_safe("res://assets/images/quiz2/true_button.png")
		
	true_btn = TextureButton.new()
	true_btn.ignore_texture_size = true
	true_btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	true_btn.texture_normal = true_tex
	true_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	true_btn.focus_mode = Control.FOCUS_NONE
	true_btn.pressed.connect(func(): _on_answer_submitted(true))
	tf_hbox.add_child(true_btn)
	
	var false_tex = UIHelper.load_texture_safe("res://assets/images/quizpage1/red_false_button.png")
	if not false_tex:
		false_tex = UIHelper.load_texture_safe("res://assets/images/quiz2/red_false_button.png")
		
	false_btn = TextureButton.new()
	false_btn.ignore_texture_size = true
	false_btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	false_btn.texture_normal = false_tex
	false_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	false_btn.focus_mode = Control.FOCUS_NONE
	false_btn.pressed.connect(func(): _on_answer_submitted(false))
	tf_hbox.add_child(false_btn)
	
	# Open Question Container for Open / Exploration Questions
	open_input_container = VBoxContainer.new()
	open_input_container.alignment = BoxContainer.ALIGNMENT_CENTER
	open_input_container.add_theme_constant_override("separation", 10)
	question_container.add_child(open_input_container)
	
	text_row = VBoxContainer.new()
	text_row.alignment = BoxContainer.ALIGNMENT_CENTER
	text_row.add_theme_constant_override("separation", 10)
	open_input_container.add_child(text_row)
	
	open_line_edit = LineEdit.new()
	open_line_edit.placeholder_text = "Type your answer here..."
	open_line_edit.custom_minimum_size = Vector2(280, 52)
	open_line_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var le_st = StyleBoxFlat.new()
	le_st.bg_color = Color(0.94, 0.97, 1.0)
	le_st.set_corner_radius_all(14)
	le_st.border_width_left = 2
	le_st.border_width_right = 2
	le_st.border_width_top = 2
	le_st.border_width_bottom = 2
	le_st.border_color = Color(0.35, 0.65, 0.95)
	open_line_edit.add_theme_stylebox_override("normal", le_st)
	open_line_edit.add_theme_color_override("font_color", UIHelper.DEEP_BLUE)
	open_line_edit.add_theme_font_size_override("font_size", 16)
	open_line_edit.text_submitted.connect(func(txt):
		if txt.strip_edges() != "":
			_on_answer_submitted(txt.strip_edges())
	)
	text_row.add_child(open_line_edit)
	
	var btn_center = CenterContainer.new()
	text_row.add_child(btn_center)
	
	open_submit_btn = UIHelper.create_bubbly_button("SUBMIT ANSWER", UIHelper.VIBRANT_GREEN)
	open_submit_btn.custom_minimum_size = Vector2(260, 56)
	open_submit_btn.pressed.connect(func():
		var txt = open_line_edit.text.strip_edges()
		if txt != "":
			_on_answer_submitted(txt)
	)
	btn_center.add_child(open_submit_btn)
	
	open_options_vbox = VBoxContainer.new()
	open_options_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	open_options_vbox.add_theme_constant_override("separation", 6)
	open_input_container.add_child(open_options_vbox)
	
	# 9. Feedback View Container
	feedback_container = Control.new()
	feedback_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	feedback_container.visible = false
	card.add_child(feedback_container)
	
	feedback_header_lbl = RichTextLabel.new()
	feedback_header_lbl.bbcode_enabled = true
	feedback_header_lbl.fit_content = true
	feedback_header_lbl.scroll_active = false
	feedback_header_lbl.add_theme_constant_override("line_separation", 6)
	feedback_header_lbl.add_theme_font_size_override("normal_font_size", 16)
	feedback_header_lbl.add_theme_font_size_override("bold_font_size", 18)
	feedback_container.add_child(feedback_header_lbl)
	
	crown_img = TextureRect.new()
	crown_img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	crown_img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	feedback_container.add_child(crown_img)
	
	tip_panel = Panel.new()
	var tp_sub_style = StyleBoxFlat.new()
	tp_sub_style.bg_color = Color(1.0, 0.965, 0.85)
	tp_sub_style.set_corner_radius_all(22)
	tp_sub_style.border_width_left = 3
	tp_sub_style.border_width_right = 3
	tp_sub_style.border_width_top = 3
	tp_sub_style.border_width_bottom = 3
	tp_sub_style.border_color = Color(1.0, 0.76, 0.12)
	tip_panel.add_theme_stylebox_override("panel", tp_sub_style)
	
	tip_lbl = Label.new()
	tip_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	tip_lbl.anchor_right = 1.0
	tip_lbl.anchor_bottom = 1.0
	tip_lbl.offset_left = 14
	tip_lbl.offset_right = -14
	tip_lbl.offset_top = 4
	tip_lbl.offset_bottom = -4
	tip_lbl.text = "Top Tip: Brush to a song to make things more fun!"
	tip_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tip_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tip_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	tip_lbl.add_theme_constant_override("line_spacing", 4)
	UIHelper.apply_bubbly_label(tip_lbl, 14, Color(0.48, 0.30, 0.0), true)
	tip_panel.add_child(tip_lbl)
	feedback_container.add_child(tip_panel)
	
	next_btn = Button.new()
	next_btn.text = "NEXT"
	var nb_style = StyleBoxFlat.new()
	nb_style.bg_color = Color(0.14, 0.76, 0.30)
	nb_style.set_corner_radius_all(24)
	nb_style.border_width_left = 3
	nb_style.border_width_right = 3
	nb_style.border_width_top = 3
	nb_style.border_width_bottom = 3
	nb_style.border_color = Color.WHITE
	nb_style.shadow_color = Color(0.06, 0.38, 0.14, 0.40)
	nb_style.shadow_size = 6
	nb_style.shadow_offset = Vector2(0, 4)
	next_btn.add_theme_stylebox_override("normal", nb_style)
	var nb_hover = nb_style.duplicate()
	nb_hover.bg_color = Color(0.18, 0.82, 0.36)
	next_btn.add_theme_stylebox_override("hover", nb_hover)
	next_btn.add_theme_stylebox_override("pressed", nb_style)
	UIHelper.apply_bubbly_label(next_btn, 18, Color.WHITE, true)
	next_btn.focus_mode = Control.FOCUS_NONE
	next_btn.pressed.connect(_on_next_pressed)
	feedback_container.add_child(next_btn)

func _relayout():
	var safe_sz = UIHelper.get_viewport_safe_size(self)
	var cur_w = safe_sz.x
	var cur_h = safe_sz.y
	var is_tablet = cur_w >= 560
	
	if bg:
		bg.size = safe_sz
		
	if back_btn:
		back_btn.position = Vector2(14, 12)
	if stats_vbox:
		stats_vbox.position = Vector2(cur_w - 114, 10)
		
	var title_w = min(cur_w - 60.0, 310.0 if not is_tablet else 420.0)
	var title_h = 58.0 if not is_tablet else 76.0
	if title_rect:
		title_rect.position = Vector2((cur_w - title_w) * 0.5, 10.0)
		title_rect.size = Vector2(title_w, title_h)
	elif title_lbl:
		title_lbl.position = Vector2((cur_w - title_w) * 0.5, 10.0)
		title_lbl.size = Vector2(title_w, title_h)
		title_lbl.add_theme_font_size_override("font_size", 32 if not is_tablet else 40)
		
	if dots_hbox:
		dots_hbox.anchor_left = 0.0
		dots_hbox.anchor_right = 1.0
		dots_hbox.offset_left = 0.0
		dots_hbox.offset_right = 0.0
		dots_hbox.position = Vector2(0.0, 76.0 if not is_tablet else 94.0)
		dots_hbox.size = Vector2(cur_w, 20.0)
		dots_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
		
	if card:
		var card_w = min(380.0 if not is_tablet else 480.0, cur_w - 32.0)
		var card_top = 138.0 if not is_tablet else 160.0
		var card_h = clamp(cur_h - card_top - 20.0, 440.0, 580.0)
		card.size = Vector2(card_w, card_h)
		card.position = Vector2((cur_w - card_w) * 0.5, card_top)
		
		if tab_pill:
			var tp_w = 210.0 if not is_tablet else 250.0
			var tp_h = 40.0
			tab_pill.size = Vector2(tp_w, tp_h)
			tab_pill.position = Vector2((card_w - tp_w) * 0.5, -20.0)
			
		if question_container:
			var tf_w = card_w - 36.0
			var btn_h = 74.0 if not is_tablet else 86.0
			var tf_y = card_h - btn_h - 20.0
			
			if tf_hbox:
				tf_hbox.position = Vector2(18.0, tf_y)
				tf_hbox.size = Vector2(tf_w, btn_h)
				var btn_w = (tf_w - 14.0) * 0.5
				if true_btn:
					true_btn.custom_minimum_size = Vector2(btn_w, btn_h)
					true_btn.pivot_offset = Vector2(btn_w * 0.5, btn_h * 0.5)
				if false_btn:
					false_btn.custom_minimum_size = Vector2(btn_w, btn_h)
					false_btn.pivot_offset = Vector2(btn_w * 0.5, btn_h * 0.5)
					
			var open_h = 128.0 if not is_tablet else 140.0
			var open_y = card_h - open_h - 18.0
			if open_input_container:
				open_input_container.position = Vector2(18.0, open_y)
				open_input_container.size = Vector2(tf_w, open_h)
					
			if question_text:
				var q_top = 30.0
				var is_open = (open_input_container and open_input_container.visible) or is_baseline or (current_question_idx < questions.size() and _is_open_question(questions[current_question_idx]))
				var q_avail_h = (open_y - q_top - 10.0) if is_open else (tf_y - q_top - 10.0)
				question_text.position = Vector2(16.0, q_top)
				question_text.size = Vector2(card_w - 32.0, max(60.0, q_avail_h))
				
		if feedback_container:
			var hdr_h = 68.0
			var hdr_y = 28.0
			if feedback_header_lbl:
				feedback_header_lbl.position = Vector2(18.0, hdr_y)
				feedback_header_lbl.size = Vector2(card_w - 36.0, hdr_h)
				
			var nb_w = 180.0
			var nb_h = 50.0
			var nb_y = card_h - nb_h - 18.0
			if next_btn:
				next_btn.position = Vector2((card_w - nb_w) * 0.5, nb_y)
				next_btn.size = Vector2(nb_w, nb_h)
				
			var tip_w = card_w - 36.0
			var tip_h = 54.0
			var tip_y = nb_y - tip_h - 14.0
			if tip_panel:
				tip_panel.position = Vector2((card_w - tip_w) * 0.5, tip_y)
				tip_panel.size = Vector2(tip_w, tip_h)
				
			if crown_img:
				var avail_h = tip_y - (hdr_y + hdr_h) - 10.0
				var img_size = clamp(avail_h, 160.0, min(card_w - 40.0, 220.0))
				crown_img.position = Vector2((card_w - img_size) * 0.5, (hdr_y + hdr_h) + (avail_h - img_size) * 0.5)
				crown_img.size = Vector2(img_size, img_size)
				crown_img.pivot_offset = Vector2(img_size * 0.5, img_size * 0.5)

func _update_dots():
	if not dots_hbox:
		return
	for c in dots_hbox.get_children():
		c.queue_free()
		
	var total_q = questions.size()
	if total_q <= 0:
		total_q = 7
	var is_compact = total_q > 7
	dots_hbox.add_theme_constant_override("separation", 4 if is_compact else 8)
	
	for i in range(total_q):
		var dot = Panel.new()
		var d_style = StyleBoxFlat.new()
		d_style.border_width_left = 1 if is_compact else 2
		d_style.border_width_right = 1 if is_compact else 2
		d_style.border_width_top = 1 if is_compact else 2
		d_style.border_width_bottom = 1 if is_compact else 2
		d_style.border_color = Color.WHITE
		d_style.set_corner_radius_all(6)
		
		if i == current_question_idx:
			var w = 24 if is_compact else 32
			dot.custom_minimum_size = Vector2(w, 14)
			dot.size = Vector2(w, 14)
			d_style.bg_color = Color(1.0, 0.76, 0.12) # Gold current
		elif i < results.size() and results[i] != null:
			var w = 16 if is_compact else 24
			dot.custom_minimum_size = Vector2(w, 14)
			dot.size = Vector2(w, 14)
			var q_item = questions[i] if i < questions.size() else {}
			if is_baseline or _is_open_question(q_item):
				d_style.bg_color = Color(0.20, 0.65, 0.95) # Cyan/Blue for completed open questions
			elif results[i] == true:
				d_style.bg_color = Color(0.14, 0.65, 0.17) # Green for correct True/False
			else:
				d_style.bg_color = Color(0.88, 0.13, 0.16) # Red for incorrect True/False
		else:
			var w = 12 if is_compact else 16
			dot.custom_minimum_size = Vector2(w, 14)
			dot.size = Vector2(w, 14)
			d_style.bg_color = Color(1.0, 1.0, 1.0, 0.35) # Translucent white
			
		dot.add_theme_stylebox_override("panel", d_style)
		dots_hbox.add_child(dot)

static func clean_question_text(raw_text: String) -> String:
	var cleaned = raw_text.strip_edges()
	var regex = RegEx.new()
	regex.compile("^(Day\\s*\\d+\\s*(Preview|Recap)?\\s*:\\s*|Championship\\s*:\\s*|Part\\s*\\d+\\s*(:\\s*|\\s*•\\s*|\\s*-\\s*)?)")
	var m = regex.search(cleaned)
	if m:
		cleaned = cleaned.substr(m.get_end()).strip_edges()
	if cleaned.begins_with("Preview: "):
		cleaned = cleaned.substr(9).strip_edges()
	elif cleaned.begins_with("Recap: "):
		cleaned = cleaned.substr(7).strip_edges()
	return cleaned

func _is_open_question(q: Dictionary) -> bool:
	if is_baseline:
		return true
	if q.get("type", "") == "open":
		return true
	if q.get("section", "") == "PREVIEW":
		return true
	if not q.has("a") or typeof(q.get("a", null)) != TYPE_BOOL:
		return true
	return false

func _show_question():
	if current_question_idx >= questions.size():
		_show_results()
		return
		
	_update_dots()
	var q = questions[current_question_idx]
	question_tab_label.text = "QUESTION %d" % (current_question_idx + 1)
	question_text.text = clean_question_text(q.get("q", ""))
	
	if _is_open_question(q):
		tf_hbox.visible = false
		open_input_container.visible = true
		text_row.visible = true
		open_line_edit.text = ""
		open_line_edit.placeholder_text = "Type what you think..."
		
		# Open questions are open-ended only (no multiple choice buttons)
		for c in open_options_vbox.get_children():
			c.queue_free()
		open_options_vbox.visible = false
	else:
		tf_hbox.visible = true
		open_input_container.visible = false
	
	question_container.visible = true
	feedback_container.visible = false
	_relayout()

func _on_answer_submitted(user_choice):
	var q = questions[current_question_idx]
	
	if _is_open_question(q):
		var ans_str = str(user_choice).strip_edges()
		if ans_str == "":
			return
			
		baseline_answers.append({
			"index": current_question_idx,
			"day": q.get("day", current_question_idx + 1),
			"question": clean_question_text(q.get("q", "")),
			"concept": q.get("concept", ""),
			"answer": ans_str,
			"timestamp": Time.get_unix_time_from_system()
		})

		# FIX: Ensure results array is properly sized before accessing
		while results.size() <= current_question_idx:
			results.append(null)
		results[current_question_idx] = true
		_update_dots()
		
		# Award coins and points for writing reflection
		GameState.add_molar_coins(15)
		GameState.add_points(25)
		AudioManager.play_sfx("cheer")
		
		# Show instant reward celebration feedback
		crown_img.texture = UIHelper.load_texture_safe("res://assets/images/quiz2/sircrown_correct.png")
		feedback_header_lbl.text = "[center][b][color=#1eb038]Great Reflection![/color][/b]\n[color=#153866]Sir Crown says: \"Awesome thinking! Your response has been saved to your Scrapbook!\"[/color]\n[b][color=#e69d00]💰 +15 Molar Coins! ⭐ +25 Hero Points![/color][/b][/center]"
		
		var raw_tip = q.get("tip", "Brush twice every day for 2 whole minutes!")
		if raw_tip.begins_with("Day ") and "Fact: " in raw_tip:
			var idx = raw_tip.find("Fact: ")
			raw_tip = raw_tip.substr(idx + 6).strip_edges()
		tip_lbl.text = "Top Tip: %s" % raw_tip
		
		if current_question_idx + 1 >= questions.size():
			next_btn.text = "FINISH"
		else:
			next_btn.text = "NEXT"
			
		question_container.visible = false
		feedback_container.visible = true
		_relayout()
		
		crown_img.scale = Vector2(0.85, 0.85)
		var tw = crown_img.create_tween()
		tw.tween_property(crown_img, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		return
		
	# True / False recap question
	# FIX: Ensure results array is properly sized before accessing
	var is_correct = (user_choice == q.get("a", false))
	while results.size() <= current_question_idx:
		results.append(null)
	results[current_question_idx] = is_correct
	_update_dots()
	
	var why_text = q.get("why", q.get("explanation", ""))
	if is_correct:
		correct_answers += 1
		AudioManager.play_sfx("cheer")
		crown_img.texture = UIHelper.load_texture_safe("res://assets/images/quiz2/sircrown_correct.png")
		feedback_header_lbl.text = "[center][b][color=#1eb038]Yes![/color][/b] [color=#153866]%s[/color][/center]" % why_text
	else:
		AudioManager.play_sfx("hit")
		crown_img.texture = UIHelper.load_texture_safe("res://assets/images/quiz2/sircrown_incorrect.png")
		var ans_display = "True" if q.get("a", false) else "False"
		feedback_header_lbl.text = "[center][b][color=#e02626]Not quite![/color][/b] [color=#153866]The answer is %s. %s[/color][/center]" % [ans_display, why_text]
		
	var raw_tip = q.get("tip", "Brush twice every day for 2 whole minutes!")
	if raw_tip.begins_with("Day ") and "Fact: " in raw_tip:
		var idx = raw_tip.find("Fact: ")
		raw_tip = raw_tip.substr(idx + 6).strip_edges()
	tip_lbl.text = "Top Tip: %s" % raw_tip
	
	# Update button text on last question
	if current_question_idx + 1 >= questions.size():
		next_btn.text = "FINISH"
	else:
		next_btn.text = "NEXT"
		
	question_container.visible = false
	feedback_container.visible = true
	_relayout()
	
	crown_img.scale = Vector2(0.85, 0.85)
	var tw = crown_img.create_tween()
	tw.tween_property(crown_img, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _on_next_pressed():
	AudioManager.play_sfx("click")
	current_question_idx += 1
	_show_question()

func _on_back_pressed():
	AudioManager.play_sfx("click")
	if current_question_idx >= questions.size():
		quiz_completed.emit()
		return
	_show_confirm_back_modal()

func _show_confirm_back_modal():
	if confirm_back_modal and is_instance_valid(confirm_back_modal):
		confirm_back_modal.queue_free()
		
	var dlg = UIHelper.create_modal_dialog(self, 150, Color(0.04, 0.10, 0.24, 0.70))
	confirm_back_modal = dlg["overlay"]
	var center = dlg["center"]
	
	var card_w = 330.0
	var card_h = 220.0
	var c_panel = Panel.new()
	c_panel.custom_minimum_size = Vector2(card_w, card_h)
	c_panel.size = Vector2(card_w, card_h)
	c_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	c_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var p_st = StyleBoxFlat.new()
	p_st.bg_color = Color(1.0, 1.0, 1.0, 0.98)
	p_st.set_corner_radius_all(28)
	p_st.border_width_left = 4
	p_st.border_width_right = 4
	p_st.border_width_top = 4
	p_st.border_width_bottom = 4
	p_st.border_color = Color.WHITE
	p_st.shadow_color = Color(0.08, 0.28, 0.52, 0.28)
	p_st.shadow_size = 18
	p_st.shadow_offset = Vector2(0, 8)
	c_panel.add_theme_stylebox_override("panel", p_st)
	center.add_child(c_panel)
	
	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 22.0
	vbox.offset_right = -22.0
	vbox.offset_top = 22.0
	vbox.offset_bottom = -22.0
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 14)
	c_panel.add_child(vbox)
	
	var heading = Label.new()
	heading.text = "Are you sure?"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIHelper.apply_bubbly_label(heading, 22, UIHelper.DEEP_BLUE, true)
	vbox.add_child(heading)
	
	var desc = Label.new()
	desc.text = "You will lose this progress and have to take the quiz again."
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	UIHelper.apply_bubbly_label(desc, 13, Color(0.18, 0.42, 0.70), true)
	vbox.add_child(desc)
	
	var btn_row = HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 12)
	vbox.add_child(btn_row)
	
	var keep_btn = UIHelper.create_themed_button("keepgoing", Vector2(130, 44))
	if not keep_btn.texture_normal:
		keep_btn = UIHelper.create_bubbly_button("Keep Going", UIHelper.VIBRANT_GREEN)
		keep_btn.custom_minimum_size = Vector2(130, 44)
	keep_btn.pressed.connect(func():
		AudioManager.play_sfx("click")
		confirm_back_modal.queue_free()
		confirm_back_modal = null
	)
	btn_row.add_child(keep_btn)
	
	var leave_btn = UIHelper.create_themed_button("leave", Vector2(130, 44))
	if not leave_btn.texture_normal:
		leave_btn = UIHelper.create_bubbly_button("Leave", Color(0.88, 0.32, 0.32))
		leave_btn.custom_minimum_size = Vector2(130, 44)
	leave_btn.pressed.connect(func():
		AudioManager.play_sfx("click")
		confirm_back_modal.queue_free()
		confirm_back_modal = null
		quiz_completed.emit()
	)
	btn_row.add_child(leave_btn)
	
	c_panel.scale = Vector2(0.85, 0.85)
	c_panel.pivot_offset = Vector2(card_w * 0.5, card_h * 0.5)
	var tw = c_panel.create_tween()
	tw.tween_property(c_panel, "scale", Vector2.ONE, 0.20).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _show_results():
	var p = GameState.get_active_profile()
	
	var total_graded = 0
	for q in questions:
		if not _is_open_question(q):
			total_graded += 1
	if total_graded == 0:
		total_graded = questions.size()

	# FIX: Baseline quizzes now grant participation rewards (100 points, 50 coins)
	# regardless of True/False score, eliminating farming exploit
	var pts_earned = 100 if is_baseline else (correct_answers * 20 + 60)
	var coins_earned = 50 if is_baseline else (correct_answers * 3 + 10)
	
	p["points"] = int(round(float(p.get("points", 0)))) + pts_earned
	p["coins"] = int(round(float(p.get("coins", 0)))) + coins_earned
	p["quizzesCompleted"] = p.get("quizzesCompleted", 0) + 1
	
	if is_baseline:
		p["baseline_quiz_answers"] = baseline_answers
	else:
		var is_perfect = (correct_answers >= total_graded)
		if is_perfect:
			p["quizPerfect"] = true
			var unlocked = p.get("unlockedCharacters", ["chip", "flora"])
			if not unlocked.has("spark"):
				unlocked.append("spark")
				p["unlockedCharacters"] = unlocked
				GameState.push_achievement("New Champion!", "Spark has joined your team!", "Unlocked with a perfect quiz score!", 100, "spark", "", 200)

	# 1. Log each question's answer (True/False and open-text preview) to FirebaseManager
	var day_for_quiz = 0 if is_baseline else (week_num * 7)
	for i in range(questions.size()):
		var q_data = questions[i]
		var q_id = "q_%02d" % (i + 1)
		var is_open = _is_open_question(q_data)
		var is_corr = (results[i] == true) if (not is_open and i < results.size()) else true
		var q_type = "open_text" if is_open else "true_false"
		var user_ans = "completed"
		if is_open:
			for b in baseline_answers:
				if b.get("index", -1) == i or b.get("question", "") == clean_question_text(q_data.get("q", "")):
					user_ans = b.get("answer", "completed")
					break
		else:
			user_ans = q_data.get("a", false) if is_corr else not q_data.get("a", false)
		FirebaseManager.record_quiz_answer(day_for_quiz, q_id, q_type, user_ans, is_corr)
		# Also keep the result on this player's own profile (the Firebase record is shared by the whole device)
		if not is_open:
			var qa = p.get("quizAnswers", {})
			if typeof(qa) != TYPE_DICTIONARY:
				qa = {}
			qa["%d_%s" % [day_for_quiz, q_id]] = is_corr
			p["quizAnswers"] = qa
	
	# 2. Reward weapon ammo inventory (paste tubes & floss meters)
	if not p.has("ammo") or typeof(p["ammo"]) != TYPE_DICTIONARY:
		p["ammo"] = {"brushes": 40, "paste": 15, "wash": 10, "floss": 5}
	p["ammo"]["paste"] = int(p["ammo"].get("paste", 15)) + (10 if is_baseline else (correct_answers * 2))
	p["ammo"]["floss"] = int(p["ammo"].get("floss", 5)) + (5 if is_baseline else (correct_answers * 1))
	
	GameState.save_game()
	GameState.stats_updated.emit(p)
	
	# 3. Cache educational data locally and push to cloud
	FirebaseManager.save_challenge_data(GameState.get_progress_dict())
	
	AudioManager.play_sfx("cheer")
	
	var dlg = UIHelper.create_modal_dialog(self, 100, Color(0.04, 0.10, 0.24, 0.70))
	var res_modal = dlg["overlay"]
	var center = dlg["center"]
	
	var card_w = 320.0
	var card_h = 400.0
	var res_card = Panel.new()
	res_card.custom_minimum_size = Vector2(card_w, card_h)
	res_card.size = Vector2(card_w, card_h)
	res_card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	res_card.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var rc_style = StyleBoxFlat.new()
	rc_style.bg_color = Color(1.0, 1.0, 1.0, 0.98)
	rc_style.set_corner_radius_all(24)
	rc_style.border_width_left = 4
	rc_style.border_width_right = 4
	rc_style.border_width_top = 4
	rc_style.border_width_bottom = 4
	rc_style.border_color = Color.WHITE
	rc_style.shadow_color = Color(0.08, 0.28, 0.52, 0.25)
	rc_style.shadow_size = 18
	rc_style.shadow_offset = Vector2(0, 8)
	res_card.add_theme_stylebox_override("panel", rc_style)
	center.add_child(res_card)
	
	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 16.0
	vbox.offset_right = -16.0
	vbox.offset_top = 18.0
	vbox.offset_bottom = -18.0
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 10)
	res_card.add_child(vbox)
	
	# Doubled Title
	var title = Label.new()
	title.text = "DISCOVERY COMPLETE!" if is_baseline else "QUIZ COMPLETE!"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIHelper.apply_bubbly_label(title, 22, UIHelper.DEEP_BLUE, true)
	vbox.add_child(title)
	
	var score_lbl = Label.new()
	if is_baseline:
		score_lbl.text = "Awesome job! You're ready to start Day 1!"
	else:
		score_lbl.text = "You scored %d / %d!" % [correct_answers, total_graded]
	score_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	UIHelper.apply_bubbly_label(score_lbl, 15, UIHelper.NAVY_BLUE, true)
	vbox.add_child(score_lbl)
	
	# Rewards row with doubled 44x44 icons
	var rew_hbox = HBoxContainer.new()
	rew_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	rew_hbox.add_theme_constant_override("separation", 12)
	
	# Coins pill
	var coin_badge = UIHelper.create_reward_badge("res://assets/images/shop/gold_tooth_coin.png", "+%d Coins" % coins_earned, Color(0.86, 0.55, 0.05), 114.0, 40.0)
	rew_hbox.add_child(coin_badge)
	
	# Points pill
	var pt_badge = UIHelper.create_reward_badge("res://assets/images/shop/purple_star_points.png", "+%d Pts" % pts_earned, Color(0.58, 0.28, 0.82), 114.0, 40.0)
	rew_hbox.add_child(pt_badge)
	
	vbox.add_child(rew_hbox)
	
	# Doubled Return / Continue button
	var btn_w = clamp(card_w - 24.0, 200.0, 260.0)
	var btn_h = 56.0
	var finish_btn = UIHelper.create_themed_button("returntomap" if not is_baseline else "start", Vector2(btn_w, btn_h))
	if not finish_btn.texture_normal:
		finish_btn = UIHelper.create_bubbly_button("LET'S GO TO DAY 1!" if is_baseline else "RETURN TO MAP", UIHelper.VIBRANT_GREEN)
		finish_btn.custom_minimum_size = Vector2(btn_w, 48)
	else:
		finish_btn.custom_minimum_size = Vector2(btn_w, btn_h)
		finish_btn.size = Vector2(btn_w, btn_h)
	finish_btn.pivot_offset = Vector2(btn_w * 0.5, btn_h * 0.5)
	finish_btn.pressed.connect(func():
		AudioManager.play_sfx("click")
		res_modal.queue_free()
		quiz_completed.emit()
	)
	
	var bc = CenterContainer.new()
	bc.add_child(finish_btn)
	vbox.add_child(bc)
