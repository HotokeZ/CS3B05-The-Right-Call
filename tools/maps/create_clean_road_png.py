#!/usr/bin/env python3
"""
Create a clean PNG with ONLY road lines - no buildings, no subdivisions.
This uses the OSM road geometries to create pure road paths.
"""

import geopandas as gpd
import matplotlib.pyplot as plt
import matplotlib.patches as patches
from PIL import Image
import numpy as np
import json
from shapely.geometry import LineString, Point
from shapely.ops import unary_union

def create_clean_roads_png(roads_file, bounds_file, output_png, output_data, line_width=2):
    """
    Create a clean PNG showing only road lines using OSM geometry.
    
    Args:
        roads_file: GeoJSON file with clean road geometries
        bounds_file: JSON with map bounds for coordinate alignment
        output_png: Where to save the clean roads PNG
        output_data: Where to save the road line coordinates
        line_width: Width of road lines in pixels
    """
    
    print("Creating clean road lines PNG...")
    
    # Load road geometries
    roads_gdf = gpd.read_file(roads_file)
    print(f"Loaded {len(roads_gdf)} road segments")
    
    # Load map bounds for alignment
    with open(bounds_file, 'r') as f:
        bounds = json.load(f)
    
    # Convert roads to same CRS as bounds (Web Mercator)
    if roads_gdf.crs != "EPSG:3857":
        roads_gdf = roads_gdf.to_crs("EPSG:3857")
    
    print(f"Map bounds: {bounds}")
    
    # Filter roads to only those within map bounds  
    minx, miny, maxx, maxy = bounds['minx'], bounds['miny'], bounds['maxx'], bounds['maxy']
    
    # Create bounding box
    from shapely.geometry import box
    bbox = box(minx, miny, maxx, maxy)
    
    # Filter roads that intersect with the bounding box
    roads_in_bounds = roads_gdf[roads_gdf.geometry.intersects(bbox)].copy()
    print(f"Roads within bounds: {len(roads_in_bounds)}")
    
    # Clip roads to exact bounds
    roads_in_bounds['geometry'] = roads_in_bounds.geometry.intersection(bbox)
    
    # Remove any empty geometries
    roads_in_bounds = roads_in_bounds[~roads_in_bounds.geometry.is_empty]
    print(f"Roads after clipping: {len(roads_in_bounds)}")
    
    # Create high-resolution image (same size as original map)
    # Use the original map size for consistency
    try:
        original_map = Image.open("assets/maps/map.png")
        img_width, img_height = original_map.size
        print(f"Using original map dimensions: {img_width}x{img_height}")
    except:
        img_width, img_height = 2048, 1468  # Fallback
        print(f"Using fallback dimensions: {img_width}x{img_height}")
    
    # Create figure with exact pixel dimensions
    dpi = 100
    fig_width = img_width / dpi
    fig_height = img_height / dpi
    
    fig, ax = plt.subplots(figsize=(fig_width, fig_height), dpi=dpi)
    
    # Set exact limits to match map bounds
    ax.set_xlim(minx, maxx)
    ax.set_ylim(miny, maxy)
    
    # Plot roads as clean red lines
    if len(roads_in_bounds) > 0:
        roads_in_bounds.plot(ax=ax, color='red', linewidth=line_width, alpha=0.9)
        print(f"Plotted {len(roads_in_bounds)} road segments")
    
    # Remove all axes, ticks, labels
    ax.set_aspect('equal')
    ax.axis('off')
    ax.set_xticks([])
    ax.set_yticks([])
    
    # Make background transparent
    fig.patch.set_alpha(0)
    ax.patch.set_alpha(0)
    
    # Save with transparent background
    plt.tight_layout()
    plt.subplots_adjust(left=0, bottom=0, right=1, top=1, wspace=0, hspace=0)
    
    plt.savefig(output_png, dpi=dpi, bbox_inches='tight', pad_inches=0, 
                facecolor='none', edgecolor='none', transparent=True)
    plt.close()
    
    print(f"Saved clean roads PNG: {output_png}")
    
    # Extract road line coordinates for patrol generation
    road_points = []
    
    for idx, road in roads_in_bounds.iterrows():
        geom = road.geometry
        
        if hasattr(geom, 'coords'):  # LineString
            coords = list(geom.coords)
        elif hasattr(geom, 'geoms'):  # MultiLineString
            coords = []
            for line in geom.geoms:
                if hasattr(line, 'coords'):
                    coords.extend(list(line.coords))
        else:
            continue
        
        # Convert coordinates to normalized (0-1) range
        for x, y in coords:
            norm_x = (x - minx) / (maxx - minx)
            norm_y = (y - miny) / (maxy - miny)
            
            # Flip Y coordinate to match image coordinates (top-left origin)
            norm_y = 1.0 - norm_y
            
            road_points.append({
                "x": norm_x,
                "y": norm_y,
                "original_x": x,
                "original_y": y
            })
    
    # Save road line data
    road_data = {
        "total_points": len(road_points),
        "image_dimensions": {"width": img_width, "height": img_height},
        "bounds": bounds,
        "road_segments": len(roads_in_bounds),
        "road_points": road_points
    }
    
    with open(output_data, 'w') as f:
        json.dump(road_data, f, indent=2)
    
    print(f"Saved road line data: {output_data}")
    print(f"Extracted {len(road_points)} road line points")
    
    if road_points:
        x_coords = [p['x'] for p in road_points]
        y_coords = [p['y'] for p in road_points]
        print(f"Coverage ranges:")
        print(f"  X: {min(x_coords):.3f} to {max(x_coords):.3f}")
        print(f"  Y: {min(y_coords):.3f} to {max(y_coords):.3f}")
    
    return road_points

if __name__ == "__main__":
    roads_file = "data/source/santacruz_roads.geojson"
    bounds_file = "assets/maps/map.bounds.json"
    output_png = "data/maps/clean_roads.png"
    output_data = "data/maps/clean_road_points.json"
    
    try:
        print("Creating clean road lines PNG from OSM data...")
        points = create_clean_roads_png(roads_file, bounds_file, output_png, output_data, line_width=3)
        
        print("✓ Clean road PNG created!")
        print(f"  Clean roads PNG: {output_png}")
        print(f"  Road line data: {output_data}")
        print(f"  Total road points: {len(points)}")
        
    except Exception as e:
        print(f"Error: {e}")
        import traceback
        traceback.print_exc()