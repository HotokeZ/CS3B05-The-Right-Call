#!/usr/bin/env python3
"""
Create a layered map system with base map and road overlay.
This provides better visualization by separating the base terrain from road data.
"""

import contextily as ctx
import geopandas as gpd
from shapely.geometry import box
import matplotlib.pyplot as plt
import numpy as np
from PIL import Image
import json

def create_base_map(bounds_file, output_path, map_style='OpenStreetMap.Mapnik'):
    """
    Create a clean base map using OpenStreetMap tiles.
    
    Args:
        bounds_file: JSON file containing map bounds
        output_path: Where to save the base map
        map_style: Tile source style
    """
    
    # Load bounds
    with open(bounds_file, 'r') as f:
        bounds = json.load(f)
    
    print(f"Creating base map with bounds: {bounds}")
    
    # Create bounding box geometry
    minx, miny, maxx, maxy = bounds['minx'], bounds['miny'], bounds['maxx'], bounds['maxy']
    bbox = box(minx, miny, maxx, maxy)
    
    # Create GeoDataFrame with the bounding box
    gdf = gpd.GeoDataFrame([1], geometry=[bbox], crs="EPSG:4326")
    
    # Convert to Web Mercator for tile downloading
    gdf_mercator = gdf.to_crs("EPSG:3857")
    
    # Create figure
    fig, ax = plt.subplots(1, 1, figsize=(12, 12), dpi=100)
    ax.set_aspect('equal')
    
    # Plot the bounding box (invisible, just for extent)
    gdf_mercator.plot(ax=ax, color='none', edgecolor='none')
    
    # Add base map tiles
    try:
        # Use OpenStreetMap for a clean base map
        ctx.add_basemap(ax, crs=gdf_mercator.crs, source=map_style, alpha=1.0)
        print(f"Added {map_style} base map")
    except Exception as e:
        print(f"Warning: Could not add {map_style}: {e}")
        # Fallback to default
        ctx.add_basemap(ax, crs=gdf_mercator.crs, alpha=1.0)
        print("Added default base map")
    
    # Remove axes and margins
    ax.set_xlim(gdf_mercator.total_bounds[0], gdf_mercator.total_bounds[2])
    ax.set_ylim(gdf_mercator.total_bounds[1], gdf_mercator.total_bounds[3])
    ax.axis('off')
    
    # Save with tight layout
    plt.tight_layout()
    plt.savefig(output_path, dpi=300, bbox_inches='tight', pad_inches=0, 
                facecolor='white', edgecolor='none')
    plt.close()
    
    print(f"Saved base map to: {output_path}")

def create_layered_visualization(base_map_path, road_overlay_path, output_path, opacity=0.8):
    """
    Combine base map with road overlay for better visualization.
    
    Args:
        base_map_path: Path to base map PNG
        road_overlay_path: Path to road overlay PNG (with transparency)
        output_path: Where to save the combined image
        opacity: Opacity of the road overlay (0-1)
    """
    
    # Load images
    base_img = Image.open(base_map_path).convert('RGBA')
    
    try:
        road_img = Image.open(road_overlay_path).convert('RGBA')
    except FileNotFoundError:
        print(f"Road overlay not found: {road_overlay_path}")
        print("Using base map only")
        base_img.save(output_path)
        return
    
    print(f"Base map size: {base_img.size}")
    print(f"Road overlay size: {road_img.size}")
    
    # Resize road overlay to match base map if needed
    if base_img.size != road_img.size:
        print("Resizing road overlay to match base map")
        road_img = road_img.resize(base_img.size, Image.Resampling.LANCZOS)
    
    # Adjust road overlay opacity
    if opacity < 1.0:
        # Get alpha channel and reduce it
        r, g, b, a = road_img.split()
        a = a.point(lambda x: int(x * opacity))
        road_img = Image.merge('RGBA', (r, g, b, a))
    
    # Composite the images
    combined = Image.alpha_composite(base_img, road_img)
    
    # Save result
    combined.save(output_path, 'PNG')
    print(f"Saved layered map to: {output_path}")

def analyze_road_coverage(road_pixels_path):
    """
    Analyze the road pixel coverage to provide statistics.
    """
    
    with open(road_pixels_path, 'r') as f:
        data = json.load(f)
    
    pixels = data['road_pixels']
    dims = data['image_dimensions']
    
    total_image_pixels = dims['width'] * dims['height']
    road_pixel_count = data['total_pixels']
    coverage_percent = (road_pixel_count / total_image_pixels) * 100
    
    print(f"\nRoad Coverage Analysis:")
    print(f"  Image dimensions: {dims['width']} x {dims['height']}")
    print(f"  Total image pixels: {total_image_pixels:,}")
    print(f"  Road pixels found: {road_pixel_count:,}")
    print(f"  Road coverage: {coverage_percent:.2f}%")
    print(f"  Sampled points: {len(pixels):,}")
    
    if pixels:
        x_coords = [p['x'] for p in pixels]
        y_coords = [p['y'] for p in pixels]
        
        print(f"  Sampled coverage:")
        print(f"    X range: {min(x_coords):.3f} to {max(x_coords):.3f}")
        print(f"    Y range: {min(y_coords):.3f} to {max(y_coords):.3f}")

if __name__ == "__main__":
    # File paths
    bounds_file = "assets/maps/map.bounds.json"
    base_map_output = "data/maps/base_map.png"
    road_overlay_input = "data/maps/road_overlay.png"
    layered_output = "data/maps/layered_map.png"
    road_pixels_file = "data/maps/road_pixels.json"
    
    try:
        # Create output directory
        import os
        os.makedirs("data", exist_ok=True)
        
        print("Creating layered map system...")
        
        # Create base map
        if os.path.exists(bounds_file):
            print("Creating clean base map...")
            create_base_map(bounds_file, base_map_output, 'OpenStreetMap.Mapnik')
        else:
            print(f"Bounds file not found: {bounds_file}")
            print("Skipping base map creation")
        
        # Create layered visualization
        if os.path.exists(base_map_output) and os.path.exists(road_overlay_input):
            print("Combining base map with road overlay...")
            create_layered_visualization(base_map_output, road_overlay_input, layered_output, opacity=0.7)
        else:
            print("Missing base map or road overlay - skipping layered visualization")
        
        # Analyze road coverage
        if os.path.exists(road_pixels_file):
            analyze_road_coverage(road_pixels_file)
        
        print("\n✓ Layered map system created!")
        print(f"  Base map: {base_map_output}")
        print(f"  Layered map: {layered_output}")
        
    except Exception as e:
        print(f"Error: {e}")
        import traceback
        traceback.print_exc()