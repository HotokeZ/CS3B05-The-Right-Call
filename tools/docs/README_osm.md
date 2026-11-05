OSM extraction and Godot integration
==================================

This folder contains helper scripts to download OpenStreetMap data for Santa Cruz, Laguna
and export simplified, normalized point lists that are easy to load into Godot.

Files
-----
- `tools/osm_extract_santacruz.py` — downloads the place polygon, driving road network, and barangay polygons (admin_level=10) and writes GeoJSON into `data/`.
- `tools/export_normalized_points.py` — reads the exported roads GeoJSON, samples points along road segments, and writes a normalized JSON (`data/santacruz_roads_points.json`) with coordinates in [0,1].

Requirements
------------
Install the Python dependencies (recommend inside a virtualenv):

```bash
pip install -r requirements.txt
# or if you prefer to install only what's needed:
pip install osmnx geopandas shapely fiona rtree
```

Run the extractor
-----------------

```bash
python tools/osm_extract_santacruz.py
```

This will create `data/santacruz_roads.geojson`, `data/santacruz_barangays.geojson`,
and `data/santacruz_place.geojson` (plus a bbox JSON).

Export normalized points for Godot
---------------------------------

```bash
python tools/export_normalized_points.py
```

This writes `data/santacruz_roads_points.json` with the structure:

```json
{
  "bounds": [minx, miny, maxx, maxy],
  "points": [[x_norm, y_norm], ...]
}
```

Using the normalized points in Godot
-----------------------------------

1. Decide on a background image size (width, height) that will represent the game map. The normalized coordinates map to pixels as:

   - pixel_x = x_norm * image_width
   - pixel_y = (1 - y_norm) * image_height

   (We flip the Y because projected coordinates increase upward while image Y typically increases downward.)

2. Example GDScript to load the normalized points and animate a pin along a Path2D:

```gdscript
extends Node2D

@onready var points_file = "res://data/santacruz_roads_points.json"
var image_width = 1024
var image_height = 1024

func _ready():
    var f = FileAccess.open(points_file, FileAccess.READ)
    if not f:
        push_error("Cannot open points file: %s" % points_file)
        return
    var txt = f.get_as_text()
    var parsed = JSON.parse_string(txt)
    var data = parsed.result if parsed is Dictionary and parsed.has("result") else parsed
    var pts = data["points"]

    # create a Path2D + Curve2D
    var path = Path2D.new()
    var curve = Curve2D.new()
    for p in pts:
        var px = float(p[0]) * image_width
        var py = (1.0 - float(p[1])) * image_height
        curve.add_point(Vector2(px, py))
    path.curve = curve
    add_child(path)

    var pf = PathFollow2D.new()
    path.add_child(pf)
    var pin = Sprite2D.new()
    pin.texture = preload("res://pin.png")
    pf.add_child(pin)

    pf.unit_offset = 0
    var tween = get_tree().create_tween()
    tween.tween_property(pf, "unit_offset", 1.0, 10.0)
```

Notes and next steps
--------------------
- The normalized points include many samples from all roads; you may want to compute specific routes between two points. For that, use the OSMnx graph to compute shortest paths (see the OSMnx docs) and export only that route as a list of coordinates.
- If your background image is a tileset or has georeference information (zoom, x,y tile indices), you can compute exact pixel coordinates using slippy tile math instead of normalized coordinates. I can add that if you provide tile/zoom details.
- The barangay GeoJSON (`data/santacruz_barangays.geojson`) can be used to show administrative boundaries; it includes a `name` property when available.

If you want, I can now:
- run the extractor here (if you want me to try installing dependencies and running it), or
- implement a route-exporter that creates point lists for origin/destination pairs, or
- add a Godot plugin that draws barangay polygons and labels.

Tell me which next step you prefer.
