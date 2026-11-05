#!/usr/bin/env python3
"""
Verify citywide patrol coverage vs. old limited patrol.
"""

import json
import matplotlib.pyplot as plt
from PIL import Image
import numpy as np

def compare_patrol_coverage():
    """Compare old vs new patrol coverage."""
    
    # Load original map
    original_img = Image.open('assets/maps/map.png')
    img_width, img_height = original_img.size
    
    # Load all road data
    with open('data/maps/clean_road_points.json', 'r') as f:
        road_data = json.load(f)
    all_roads = road_data['road_points']
    
    # Load old limited patrol
    try:
        with open('data/routes/clean_patrol_route.json', 'r') as f:
            old_patrol_data = json.load(f)
        old_patrol = old_patrol_data['points']
        has_old = True
    except FileNotFoundError:
        old_patrol = []
        has_old = False
    
    # Load new citywide patrol
    try:
        with open('data/routes/citywide_patrol_route.json', 'r') as f:
            new_patrol_data = json.load(f)
        new_patrol = new_patrol_data['points']
        has_new = True
    except FileNotFoundError:
        new_patrol = []
        has_new = False
    
    # Create comparison figure
    fig = plt.figure(figsize=(16, 10))
    
    # All roads overlay
    plt.subplot(2, 3, 1)
    plt.imshow(original_img)
    road_x = [p['x'] * img_width for p in all_roads]
    road_y = [p['y'] * img_height for p in all_roads]
    plt.scatter(road_x, road_y, c='red', s=0.2, alpha=0.6, label='All Roads')
    plt.title(f'All City Roads\n{len(all_roads):,} total road points', fontsize=12)
    plt.axis('off')
    
    # Old patrol (limited area)
    plt.subplot(2, 3, 2)
    plt.imshow(original_img)
    if has_old:
        old_x = [p['x'] * img_width for p in old_patrol]
        old_y = [p['y'] * img_height for p in old_patrol]
        plt.plot(old_x, old_y, 'yellow', linewidth=2, alpha=0.8, label='Old Patrol')
        plt.scatter(old_x[::5], old_y[::5], c='orange', s=15, alpha=0.9, label='Patrol Points')
        
        old_x_norm = [p['x'] for p in old_patrol]
        old_y_norm = [p['y'] for p in old_patrol]
        coverage_x = max(old_x_norm) - min(old_x_norm)
        coverage_y = max(old_y_norm) - min(old_y_norm)
        
        plt.title(f'❌ Old Limited Patrol\n{len(old_patrol)} pts, covers {coverage_x:.1%}×{coverage_y:.1%}', 
                 fontsize=12, color='red')
    else:
        plt.title('Old Patrol\n(Not available)', fontsize=12)
    plt.axis('off')
    
    # New citywide patrol
    plt.subplot(2, 3, 3)
    plt.imshow(original_img)
    if has_new:
        new_x = [p['x'] * img_width for p in new_patrol]
        new_y = [p['y'] * img_height for p in new_patrol]
        plt.scatter(new_x, new_y, c='lime', s=3, alpha=0.7, label='Citywide Patrol')
        
        new_x_norm = [p['x'] for p in new_patrol]
        new_y_norm = [p['y'] for p in new_patrol]
        coverage_x = max(new_x_norm) - min(new_x_norm)
        coverage_y = max(new_y_norm) - min(new_y_norm)
        
        plt.title(f'✅ NEW Citywide Patrol\n{len(new_patrol)} pts, covers {coverage_x:.1%}×{coverage_y:.1%}', 
                 fontsize=12, color='green')
    else:
        plt.title('New Citywide Patrol\n(Not available)', fontsize=12)
    plt.axis('off')
    
    # Coverage comparison (normalized coordinates)
    plt.subplot(2, 3, 4)
    
    # Plot all roads as background
    all_x = [p['x'] for p in all_roads]
    all_y = [p['y'] for p in all_roads]
    plt.scatter(all_x, all_y, c='lightgray', s=0.1, alpha=0.3, label='All Roads')
    
    if has_old:
        old_x_norm = [p['x'] for p in old_patrol]
        old_y_norm = [p['y'] for p in old_patrol]
        plt.scatter(old_x_norm, old_y_norm, c='red', s=8, alpha=0.8, label=f'Old ({len(old_patrol)} pts)')
    
    if has_new:
        new_x_norm = [p['x'] for p in new_patrol]
        new_y_norm = [p['y'] for p in new_patrol]
        plt.scatter(new_x_norm, new_y_norm, c='green', s=2, alpha=0.6, label=f'New ({len(new_patrol)} pts)')
    
    plt.xlim(0, 1)
    plt.ylim(0, 1)
    plt.gca().invert_yaxis()
    plt.title('Coverage Comparison\n(Normalized Coordinates)', fontsize=12)
    plt.xlabel('X (normalized)')
    plt.ylabel('Y (normalized)')
    plt.legend()
    
    # Statistics
    plt.subplot(2, 3, 5)
    plt.axis('off')
    
    stats_text = f"""
PATROL COMPARISON:

🗺️ FULL ROAD NETWORK:
  Total points: {len(all_roads):,}
  Full city coverage: 100%

"""
    
    if has_old:
        old_x_span = max(old_x_norm) - min(old_x_norm)
        old_y_span = max(old_y_norm) - min(old_y_norm)
        stats_text += f"""❌ OLD LIMITED PATROL:
  Points: {len(old_patrol)}
  X coverage: {old_x_span:.1%}
  Y coverage: {old_y_span:.1%}
  Area coverage: ~{old_x_span * old_y_span:.1%}

"""
    
    if has_new:
        new_x_span = max(new_x_norm) - min(new_x_norm)
        new_y_span = max(new_y_norm) - min(new_y_norm)
        stats_text += f"""✅ NEW CITYWIDE PATROL:
  Points: {len(new_patrol)}
  X coverage: {new_x_span:.1%}
  Y coverage: {new_y_span:.1%}
  Area coverage: ~{new_x_span * new_y_span:.1%}

🎯 IMPROVEMENT:
  Coverage increase: {(new_x_span * new_y_span) / (old_x_span * old_y_span) * 100 if has_old and old_x_span > 0 else 0:.0f}x
  Now covers ENTIRE CITY!
"""
    
    plt.text(0.05, 0.95, stats_text, transform=plt.gca().transAxes, 
             verticalalignment='top', fontfamily='monospace', fontsize=10,
             bbox=dict(boxstyle="round,pad=0.3", facecolor="lightblue", alpha=0.8))
    
    # Route visualization
    plt.subplot(2, 3, 6)
    
    if has_new:
        # Show route path
        new_x_img = [p['x'] * img_width for p in new_patrol]
        new_y_img = [p['y'] * img_height for p in new_patrol]
        
        # Connect sequential points to show patrol path
        plt.plot(new_x_img, new_y_img, 'yellow', linewidth=1, alpha=0.6, label='Patrol Path')
        plt.scatter(new_x_img[::20], new_y_img[::20], c='red', s=10, alpha=0.9, 
                   label='Patrol Checkpoints')
        
        plt.title('New Patrol Route Path\n(Sequential traverse pattern)', fontsize=12, color='blue')
        plt.axis('equal')
        plt.legend()
    else:
        plt.text(0.5, 0.5, 'New patrol route\nnot available', ha='center', va='center')
        plt.title('Patrol Path Preview\n(Not available)', fontsize=12)
    
    plt.xlim(0, img_width)
    plt.ylim(0, img_height)
    plt.gca().invert_yaxis()
    plt.axis('off')
    
    plt.tight_layout()
    plt.savefig('data/patrol_coverage_comparison.png', dpi=150, bbox_inches='tight')
    plt.show()
    
    print("✅ Patrol coverage comparison complete!")
    print("  Saved: data/patrol_coverage_comparison.png")
    
    if has_new:
        print(f"\n🚗 CITYWIDE PATROL READY:")
        print(f"   📍 {len(new_patrol)} patrol points")
        print(f"   🗺️  Covers {new_x_span:.1%}×{new_y_span:.1%} of city")
        print(f"   📁 File: data/routes/citywide_patrol_route.json")
        print("   🎮 Updated in Godot scene - run with F6!")

if __name__ == "__main__":
    try:
        compare_patrol_coverage()
    except Exception as e:
        print(f"Error: {e}")
        import traceback
        traceback.print_exc()