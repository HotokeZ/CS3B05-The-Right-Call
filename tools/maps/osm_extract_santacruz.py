"""Download OSM road network and barangay polygons for Santa Cruz, Laguna.

Usage:
  python tools/osm_extract_santacruz.py

This script uses OSMnx to:
 - geocode the place "Santa Cruz, Laguna, Philippines"
 - download the driving road network for the place
 - extract administrative boundaries at admin_level=10 (barangays)
 - export GeoJSON files under `data/`

Requirements:
  pip install osmnx geopandas shapely fiona rtree

Notes:
 - OSMnx will fetch data from the internet (Nominatim/Overpass). Make sure you have network access.
 - The exported GeoJSON files can be consumed by Godot or other tools in your pipeline.
"""
import os
import json
from pathlib import Path

def ensure_dir(p: Path):
    p.parent.mkdir(parents=True, exist_ok=True)


def main():
    place = "Santa Cruz, Laguna, Philippines"
    out_dir = Path(__file__).resolve().parent.parent / "data"
    out_dir.mkdir(parents=True, exist_ok=True)

    try:
        import osmnx as ox
        import geopandas as gpd
    except Exception as e:
        print("Missing dependencies: please pip install osmnx geopandas shapely fiona rtree")
        raise

    ox.settings.log_console = True
    ox.settings.use_cache = True

    print(f"Geocoding place: {place}")
    try:
        # get the place polygon (as GeoDataFrame)
        gdf_place = ox.geocode_to_gdf(place)
    except Exception:
        # older osmnx versions may use geocode_to_gdf differently
        gdf_place = ox.geocode_to_gdf(place)

    if gdf_place is None or gdf_place.empty:
        raise RuntimeError(f"Could not geocode place: {place}")

    # save place polygon
    place_path = out_dir / "santacruz_place.geojson"
    gdf_place.to_file(place_path, driver="GeoJSON")
    print("Saved place polygon to", place_path)

    # Download road network (drive)
    print("Downloading road network (drive)")
    G = ox.graph_from_place(place, network_type="drive")
    # simplify and project to WGS84 (nodes have x/y lon/lat in unprojected)
    G = ox.project_graph(G, to_crs="EPSG:3857")

    # Save edges as GeoJSON (LineStrings)
    edges = ox.graph_to_gdfs(G, nodes=False, edges=True, fill_edge_geometry=True)
    edges_path = out_dir / "santacruz_roads.geojson"
    edges.to_file(edges_path, driver="GeoJSON")
    print("Saved road GeoJSON to", edges_path)

    # Extract barangay polygons (admin_level=10)
    print("Downloading barangay polygons (admin_level=10)")
    tags = {"boundary": "administrative", "admin_level": "10"}
    try:
        # modern osmnx versions expose `features_from_place`
        barangays = ox.features_from_place(place, tags)
    except Exception:
        # fallback to bbox-based features query if the place-level API isn't available
        bbox = gdf_place.geometry.unary_union.bounds  # (minx, miny, maxx, maxy)
        north, south, east, west = bbox[3], bbox[1], bbox[2], bbox[0]
        try:
            barangays = ox.features_from_bbox(north, south, east, west, tags)
        except Exception:
            # older osmnx used geometries_from_* naming; try those as a last resort
            try:
                barangays = ox.geometries_from_place(place, tags)
            except Exception:
                barangays = ox.geometries_from_bbox(north, south, east, west, tags)

    if barangays is None or barangays.empty:
        print("No barangay polygons found for admin_level=10. You may need to expand the query or use a different tag.")
    else:
        # Ensure we have polygons and a name column
        if "name" not in barangays.columns:
            barangays["name"] = None
        barangays_path = out_dir / "santacruz_barangays.geojson"
        # project to EPSG:3857 for consistency with roads export
        try:
            barangays = barangays.to_crs(epsg=3857)
        except Exception:
            pass
        barangays.to_file(barangays_path, driver="GeoJSON")
        print("Saved barangays GeoJSON to", barangays_path)

    # Export bounding box and a quick metadata file
    bounds = gdf_place.geometry.unary_union.bounds  # minx,miny,maxx,maxy in lon/lat
    bbox_path = out_dir / "santacruz_bbox.json"
    with open(bbox_path, "w", encoding="utf-8") as f:
        json.dump({"place": place, "bounds": bounds}, f)
    print("Saved bbox to", bbox_path)


if __name__ == "__main__":
    main()
