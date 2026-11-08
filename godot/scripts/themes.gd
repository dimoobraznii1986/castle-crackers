class_name Themes
extends RefCounted
## Map themes ("lands"). Each theme sets the sky, ground colors, water and terrain shape.
## To add a new land: copy one block in get_theme(), change the colors, and add its id to LIST.

const LIST := ["hills", "snow", "desert", "lava"]

## Castle stone colors. Each castle gets a random one.
const STONES := [
	{"name": "Gray stone", "color": Color(0.68, 0.64, 0.56)},
	{"name": "Sandstone", "color": Color(0.84, 0.7, 0.47)},
	{"name": "Red brick", "color": Color(0.72, 0.36, 0.27)},
	{"name": "White marble", "color": Color(0.88, 0.87, 0.84)},
	{"name": "Dark slate", "color": Color(0.43, 0.45, 0.52)},
	{"name": "Mossy stone", "color": Color(0.53, 0.6, 0.45)},
]


static func get_theme(id: String) -> Dictionary:
	match id:
		"snow":
			return {
				"id": "snow", "name": "Snowy Peaks", "icon": "❄️",
				"sky": [[-600.0, Color("1d3566")], [0.0, Color("3b5b8c")], [380.0, Color("8fb4de")], [700.0, Color("dcebf8")], [900.0, Color("f2f7ff")]],
				"sun": Color("fffbe8"), "sun_edge": Color("c9d7e8"), "sun_size": 40.0,
				"mountains": [Color("e3ecf7"), Color("b8cbe4")], "mountain_line": Color(0.25, 0.32, 0.45, 0.45),
				"cloud": Color(1, 1, 1, 0.9), "cloud_shadow": Color(0.55, 0.65, 0.8, 0.35),
				"water_back": Color("3d6f9e"), "water_front": Color(0.45, 0.7, 0.9, 0.8), "water_line": Color(1, 1, 1, 0.85),
				"drop": Color(0.85, 0.95, 1.0), "lava": false, "stars": false, "snow": true,
				"ground": {
					"edge_col": Color(0.6, 0.7, 0.82), "grass_col": Color(0.94, 0.97, 1.0), "root_col": Color(0.72, 0.8, 0.9),
					"soil_dark": Color(0.3, 0.33, 0.4), "soil_light": Color(0.5, 0.54, 0.6),
					"stone_col": Color(0.19, 0.21, 0.26), "stone_hi": Color(0.85, 0.9, 0.95), "outline_col": Color(0.14, 0.16, 0.22),
				},
				"terrain": {"base": 660.0, "hill": 40.0, "hill2": 24.0, "mount_min": 210.0, "mount_max": 300.0, "mount_w": 150.0, "valley": 80.0, "islands": 1},
			}
		"desert":
			return {
				"id": "desert", "name": "Desert Dunes", "icon": "🏜️",
				"sky": [[-600.0, Color("8a3a1a")], [0.0, Color("d9732b")], [380.0, Color("f5b55c")], [700.0, Color("ffe3a3")], [900.0, Color("fff1c9")]],
				"sun": Color("fff7d0"), "sun_edge": Color("f0a030"), "sun_size": 62.0,
				"mountains": [Color("e9b27a"), Color("d08c52")], "mountain_line": Color(0.45, 0.22, 0.1, 0.4),
				"cloud": Color(1, 0.96, 0.88, 0.75), "cloud_shadow": Color(0.85, 0.55, 0.3, 0.3),
				"water_back": Color("1f7f82"), "water_front": Color(0.18, 0.66, 0.66, 0.8), "water_line": Color(0.9, 1, 0.95, 0.75),
				"drop": Color(0.7, 0.95, 0.95), "lava": false, "stars": false, "snow": false,
				"ground": {
					"edge_col": Color(0.72, 0.5, 0.22), "grass_col": Color(0.96, 0.82, 0.5), "root_col": Color(0.86, 0.66, 0.36),
					"soil_dark": Color(0.64, 0.4, 0.2), "soil_light": Color(0.86, 0.62, 0.36),
					"stone_col": Color(0.48, 0.28, 0.14), "stone_hi": Color(1.0, 0.9, 0.7), "outline_col": Color(0.42, 0.24, 0.1),
				},
				"terrain": {"base": 680.0, "hill": 48.0, "hill2": 10.0, "mount_min": 60.0, "mount_max": 130.0, "mount_w": 220.0, "valley": 60.0, "islands": 0},
			}
		"lava":
			return {
				"id": "lava", "name": "Lava Night", "icon": "🌋",
				"sky": [[-600.0, Color("05030f")], [0.0, Color("0d0a26")], [380.0, Color("2a1a4a")], [700.0, Color("5a2a52")], [900.0, Color("8a3a3a")]],
				"sun": Color("fff3d6"), "sun_edge": Color("b8a98a"), "sun_size": 30.0,
				"mountains": [Color("2c2145"), Color("3d2340")], "mountain_line": Color(1.0, 0.45, 0.15, 0.5),
				"cloud": Color(0.4, 0.33, 0.5, 0.75), "cloud_shadow": Color(0.1, 0.05, 0.15, 0.4),
				"water_back": Color("b8300c"), "water_front": Color(1.0, 0.45, 0.1, 0.88), "water_line": Color(1.0, 0.9, 0.4, 0.9),
				"drop": Color(1.0, 0.6, 0.15), "lava": true, "stars": true, "snow": false,
				"ground": {
					"edge_col": Color(1.0, 0.45, 0.1), "grass_col": Color(0.33, 0.2, 0.22), "root_col": Color(0.24, 0.13, 0.14),
					"soil_dark": Color(0.13, 0.09, 0.11), "soil_light": Color(0.28, 0.19, 0.21),
					"stone_col": Color(0.85, 0.3, 0.08), "stone_hi": Color(1.0, 0.65, 0.2), "outline_col": Color(0.95, 0.35, 0.05),
				},
				"terrain": {"base": 650.0, "hill": 30.0, "hill2": 22.0, "mount_min": 150.0, "mount_max": 230.0, "mount_w": 120.0, "valley": 120.0, "islands": 2},
			}
		_:
			return {
				"id": "hills", "name": "Green Hills", "icon": "🌳",
				"sky": [[-600.0, Color("142b66")], [0.0, Color("2a4fa8")], [405.0, Color("6fb3ef")], [700.0, Color("ffd9a0")], [900.0, Color("ffb27a")]],
				"sun": Color("fff4b8"), "sun_edge": Color("e8a640"), "sun_size": 46.0,
				"mountains": [Color("9fb4e2"), Color("7d97cf")], "mountain_line": Color(0.16, 0.2, 0.35, 0.35),
				"cloud": Color(1, 1, 1, 0.92), "cloud_shadow": Color(0.47, 0.59, 0.78, 0.35),
				"water_back": Color("1d4f99"), "water_front": Color(0.24, 0.55, 0.9, 0.82), "water_line": Color(1, 1, 1, 0.7),
				"drop": Color(0.75, 0.9, 1.0), "lava": false, "stars": false, "snow": false,
				"ground": {
					"edge_col": Color(0.12, 0.36, 0.09), "grass_col": Color(0.36, 0.72, 0.2), "root_col": Color(0.23, 0.35, 0.13),
					"soil_dark": Color(0.4, 0.25, 0.14), "soil_light": Color(0.62, 0.4, 0.24),
					"stone_col": Color(0.24, 0.16, 0.1), "stone_hi": Color(0.78, 0.66, 0.5), "outline_col": Color(0.2, 0.12, 0.06),
				},
				"terrain": {"base": 665.0, "hill": 34.0, "hill2": 18.0, "mount_min": 120.0, "mount_max": 240.0, "mount_w": 160.0, "valley": 95.0, "islands": -1},
			}
