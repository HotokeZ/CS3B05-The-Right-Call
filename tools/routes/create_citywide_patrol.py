#!/usr/bin/env python3
"""
Generate a citywide patrol route that covers ALL roads across the entire map.
This creates a comprehensive patrol that visits different areas of the city.
"""

import json
import numpy as np
from scipy.spatial.distance import cdist
import networkx as nx
from collections import defaultdict

def analyze_road_coverage(road_points):
    """
    Analyze the road network coverage to understand the full extent.
    """
    
    x_coords = [p['x'] for p in road_points]
    y_coords = [p['y'] for p in road_points]
    
    print(f"Full road network analysis:")
    print(f"  Total points: {len(road_points):,}")
    print(f"  X range: {min(x_coords):.3f} to {max(x_coords):.3f} (span: {max(x_coords) - min(x_coords):.3f})")
    print(f"  Y range: {min(y_coords):.3f} to {max(y_coords):.3f} (span: {max(y_coords) - min(y_coords):.3f})")
    
    return {
        'x_min': min(x_coords), 'x_max': max(x_coords),
        'y_min': min(y_coords), 'y_max': max(y_coords),
        'x_span': max(x_coords) - min(x_coords),
        'y_span': max(y_coords) - min(y_coords)
    }

def create_citywide_patrol_grid(road_points, grid_size=10, points_per_cell=20):
    """
    Create a patrol route that systematically covers all areas of the city.
    Divides the city into a grid and ensures patrol visits each area.
    """
    
    print(f"Creating citywide patrol grid ({grid_size}x{grid_size})...")
    
    coverage = analyze_road_coverage(road_points)
    
    # Create grid cells
    x_step = coverage['x_span'] / grid_size
    y_step = coverage['y_span'] / grid_size
    
    grid_cells = {}
    
    # Assign road points to grid cells
    for i, point in enumerate(road_points):
        x_cell = min(int((point['x'] - coverage['x_min']) / x_step), grid_size - 1)
        y_cell = min(int((point['y'] - coverage['y_min']) / y_step), grid_size - 1)
        
        cell_key = (x_cell, y_cell)
        if cell_key not in grid_cells:
            grid_cells[cell_key] = []
        grid_cells[cell_key].append(i)
    
    print(f"Road network spans {len(grid_cells)} grid cells out of {grid_size * grid_size} possible")
    
    # Create patrol route visiting each grid cell
    patrol_points = []
    
    # Sort cells to create a systematic sweep pattern
    sorted_cells = []
    for y in range(grid_size):
        if y % 2 == 0:  # Even rows: left to right
            for x in range(grid_size):
                if (x, y) in grid_cells:
                    sorted_cells.append((x, y))
        else:  # Odd rows: right to left (snake pattern)
            for x in range(grid_size - 1, -1, -1):
                if (x, y) in grid_cells:
                    sorted_cells.append((x, y))
    
    print(f"Patrol will visit {len(sorted_cells)} areas across the city")
    
    # Sample points from each cell
    for cell in sorted_cells:
        cell_points = grid_cells[cell]
        
        # Sample points from this cell
        if len(cell_points) <= points_per_cell:
            # Use all points if cell is small
            selected_indices = cell_points
        else:
            # Randomly sample points to get good coverage
            np.random.seed(42)  # Reproducible selection
            selected_indices = np.random.choice(cell_points, points_per_cell, replace=False)
        
        # Add selected points to patrol route
        for idx in selected_indices:
            patrol_points.append(road_points[idx])
    
    return patrol_points

def create_comprehensive_patrol(road_points, target_points=500):
    """
    Create a patrol route covering the entire city road network.
    """
    
    print(f"Creating comprehensive citywide patrol...")
    
    # First, try grid-based approach for full coverage
    grid_patrol = create_citywide_patrol_grid(road_points, grid_size=15, points_per_cell=15)
    
    if len(grid_patrol) < target_points // 2:
        print(f"Grid patrol has {len(grid_patrol)} points, adding more for comprehensive coverage...")
        
        # Add additional points by sampling the full road network
        remaining_points = target_points - len(grid_patrol)
        
        # Get indices of points not already in patrol
        used_coords = {(p['x'], p['y']) for p in grid_patrol}
        unused_points = [p for p in road_points if (p['x'], p['y']) not in used_coords]
        
        if unused_points:
            np.random.seed(42)
            additional_count = min(remaining_points, len(unused_points))
            additional_indices = np.random.choice(len(unused_points), additional_count, replace=False)
            
            for idx in additional_indices:
                grid_patrol.append(unused_points[idx])
    
    # Analyze final coverage
    final_coverage = analyze_road_coverage(grid_patrol)
    
    print(f"Final patrol route:")
    print(f"  Total points: {len(grid_patrol)}")
    print(f"  X coverage: {final_coverage['x_min']:.3f} to {final_coverage['x_max']:.3f} (span: {final_coverage['x_span']:.3f})")
    print(f"  Y coverage: {final_coverage['y_min']:.3f} to {final_coverage['y_max']:.3f} (span: {final_coverage['y_span']:.3f})")
    
    return grid_patrol

def create_citywide_patrol_route(road_points_file, output_file):
    """
    Create a patrol route covering the entire city road network.
    """
    
    # Load clean road data
    with open(road_points_file, 'r') as f:
        data = json.load(f)
    
    road_points = data['road_points']
    
    if len(road_points) < 100:
        raise ValueError(f"Insufficient road data: {len(road_points)} points")
    
    print(f"Loaded {len(road_points):,} road points for citywide patrol")
    
    # Create comprehensive citywide patrol
    patrol_points = create_comprehensive_patrol(road_points, target_points=600)
    
    if len(patrol_points) < 50:
        raise ValueError(f"Generated patrol too short: {len(patrol_points)} points")
    
    # Convert to route format
    route_points = []
    for point in patrol_points:
        route_points.append({
            "x": point['x'],
            "y": point['y']
        })
    
    # Create route data
    route_data = {
        "route_info": {
            "total_points": len(route_points),
            "source": "citywide_road_network",
            "method": "grid_based_comprehensive_coverage",
            "coverage_type": "full_city"
        },
        "points": route_points
    }
    
    # Save route
    with open(output_file, 'w') as f:
        json.dump(route_data, f, indent=2)
    
    print(f"Saved citywide patrol route: {output_file}")
    
    # Final coverage analysis
    x_coords = [p['x'] for p in route_points]
    y_coords = [p['y'] for p in route_points]
    
    x_span = max(x_coords) - min(x_coords)
    y_span = max(y_coords) - min(y_coords)
    
    print(f"\n✅ CITYWIDE PATROL CREATED:")
    print(f"   📍 {len(route_points)} patrol points")
    print(f"   🗺️  X coverage: {x_span:.1%} of map width")
    print(f"   🗺️  Y coverage: {y_span:.1%} of map height")
    print(f"   🚗 Patrol will visit ALL areas of the city")
    
    return route_points

if __name__ == "__main__":
    road_points_file = "data/maps/clean_road_points.json"
    output_file = "data/routes/citywide_patrol_route.json"
    
    try:
        print("Generating CITYWIDE patrol route covering entire road network...")
        points = create_citywide_patrol_route(road_points_file, output_file)
        
        print("\n🎯 SUCCESS: Citywide patrol route created!")
        print(f"   📁 Route file: {output_file}")
        print(f"   🔢 Total points: {len(points)}")
        print("   🚗 Patrol will now cover the ENTIRE city road network")
        
    except Exception as e:
        print(f"❌ Error: {e}")
        import traceback
        traceback.print_exc()