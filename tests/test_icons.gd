extends GutTest


func test_every_node_in_every_level_has_an_icon() -> void:
	for i in Content.LEVEL_COUNT:
		for node in Content.level(i).nodes:
			assert_true(ResourceLoader.exists(LevelView.node_icon_path(node)), "%s has no icon" % node.label)


func test_every_defense_has_an_icon() -> void:
	for data in Content.level(2).allowed_defenses:
		assert_true(ResourceLoader.exists(LevelView.defense_icon_path(data)), "%s has no icon" % data.display_name)


func test_compromised_workstation_has_its_own_icon() -> void:
	assert_true(ResourceLoader.exists(LevelView.COMPROMISED_ICON))


func test_icons_contain_real_pixels() -> void:
	for file_name in DirAccess.get_files_at(LevelView.ICON_DIR):
		if file_name.ends_with(".svg"):
			var image: Image = load(LevelView.ICON_DIR + file_name).get_image()
			assert_gt(image.get_pixel(48, 48).a, 0.0, "%s is empty at its center" % file_name)


## Canvas draws only keep a texture's RID, so a texture nothing holds renders as a white box.
func test_view_keeps_drawn_textures_alive() -> void:
	var view: LevelView = autofree(LevelView.new())
	var id: int = view.icon_texture(LevelView.COMPROMISED_ICON).get_instance_id()
	assert_true(is_instance_id_valid(id))
	assert_eq(view.icon_texture(LevelView.COMPROMISED_ICON).get_instance_id(), id)
	assert_true(view.is_icon_cached(LevelView.COMPROMISED_ICON))


func test_requested_future_icons_exist() -> void:
	assert_true(ResourceLoader.exists("res://art/icons/ids.svg"))
	assert_true(ResourceLoader.exists("res://art/icons/ips.svg"))


func test_entry_router_is_labelled_modem_in_every_level() -> void:
	for i in Content.LEVEL_COUNT:
		assert_eq(Content.level(i).node_def(1).label, "Modem")
