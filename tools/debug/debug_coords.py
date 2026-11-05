#!/usr/bin/env python3
"""Debug coordinate systems and bounds."""
import json
from pathlib import Path

def main():
    # Check map bounds
    bounds_file = Path("assets/maps/map.bounds.json")
    if bounds_file.exists():
        with open(bounds_file, "r") as f:
            map_bounds = json.load(f)
        print("Map bounds:", map_bounds)
    
    # Check original bbox
    bbox_file = Path("data/source/santacruz_bbox.json")
    if bbox_file.exists():
        with open(bbox_file, "r") as f:
            bbox_data = json.load(f)
        print("Original bbox:", bbox_data)
    
    # Check road geometries sample
    roads_file = Path("data/source/santacruz_roads.geojson")
    if roads_file.exists():
        try:
            import geopandas as gpd
            from pyproj import Transformer
            
            roads = gpd.read_file(roads_file)
            print(f"Roads loaded: {len(roads)} features")
            
            # Sample first few road coordinates
            transformer = Transformer.from_crs("EPSG:4326", "EPSG:3857", always_xy=True)
            
            sample_coords = []
            for i, road in roads.head(5).iterrows():
                geom = road.geometry
                if geom.geom_type == 'LineString':
                    coords = list(geom.coords)[:2]  # First 2 points
                    for lon, lat in coords:
                        x, y = transformer.transform(lon, lat)
                        sample_coords.append((lon, lat, x, y))
            
            print("Sample road coordinates (lon, lat, x_3857, y_3857):")
            for coord in sample_coords[:5]:
                print(f"  {coord[0]:.6f}, {coord[1]:.6f} -> {coord[2]:.0f}, {coord[3]:.0f}")
                
        except ImportError:
            print("Cannot check road coordinates - geopandas not available")
    
    # Check existing road points
    points_file = Path("data/source/santacruz_roads_points.json")
    if points_file.exists():
        with open(points_file, "r") as f:
            points_data = json.load(f)
        print("Existing road points bounds:", points_data.get("bounds"))

if __name__ == "__main__":
    main()