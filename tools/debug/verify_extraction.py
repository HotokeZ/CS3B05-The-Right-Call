#!/usr/bin/env python3
"""
Verify and visualize road extraction results.
Shows the original image, road mask, and patrol route.
"""

import json
import matplotlib.pyplot as plt
from PIL import Image
import numpy as np

def verify_extraction_results():
    """
    Display the road extraction results for verification.
    """
    
    # Load data
    with open('data/maps/road_pixels.json', 'r') as f:
        road_data = json.load(f)
    
    with open('data/routes/pixel_patrol_route.json', 'r') as f:
        route_data = json.load(f)
    
    # Load images
    original_img = Image.open('assets/maps/map.png')
    road_mask = Image.open('data/maps/road_mask.png')
    
    try:
        road_overlay = Image.open('data/maps/road_overlay.png')
        has_overlay = True
    except FileNotFoundError:
        has_overlay = False
    
    # Create visualization
    fig = plt.figure(figsize=(16, 12))
    
    # Original image
    plt.subplot(2, 3, 1)
    plt.imshow(original_img)
    plt.title(f'Original Satellite Image\n{original_img.size[0]}x{original_img.size[1]}')
    plt.axis('off')
    
    # Road mask
    plt.subplot(2, 3, 2)
    plt.imshow(road_mask, cmap='gray')
    plt.title(f'Road Mask\n{road_data["total_pixels"]:,} road pixels')
    plt.axis('off')
    
    # Road overlay
    plt.subplot(2, 3, 3)
    if has_overlay:
        plt.imshow(road_overlay)
        plt.title('Road Overlay\n(Roads with transparency)')
    else:
        plt.text(0.5, 0.5, 'Road overlay\nnot found', ha='center', va='center', 
                transform=plt.gca().transAxes, fontsize=12)
        plt.title('Road Overlay (Missing)')
    plt.axis('off')
    
    # Patrol route visualization
    plt.subplot(2, 3, 4)
    plt.imshow(original_img)
    
    # Plot patrol route
    route_points = route_data['points']
    img_width, img_height = original_img.size
    
    x_coords = [p['x'] * img_width for p in route_points]
    y_coords = [p['y'] * img_height for p in route_points]
    
    plt.plot(x_coords, y_coords, 'r-', linewidth=2, alpha=0.8, label='Patrol Route')
    plt.scatter(x_coords[::10], y_coords[::10], c='yellow', s=20, alpha=0.9, 
               edgecolors='red', linewidth=1, label='Patrol Points')
    
    plt.title(f'Patrol Route Overlay\n{len(route_points)} points')
    plt.axis('off')
    plt.legend()
    
    # Road pixel distribution
    plt.subplot(2, 3, 5)
    sampled_pixels = road_data['road_pixels']
    pixel_x = [p['x'] for p in sampled_pixels]
    pixel_y = [p['y'] for p in sampled_pixels]
    
    plt.scatter(pixel_x, pixel_y, c='blue', s=0.5, alpha=0.6)
    plt.title(f'Road Pixel Distribution\n{len(sampled_pixels):,} sampled points')
    plt.xlabel('X (normalized)')
    plt.ylabel('Y (normalized)')
    plt.xlim(0, 1)
    plt.ylim(0, 1)
    plt.gca().invert_yaxis()  # Match image coordinates
    
    # Statistics
    plt.subplot(2, 3, 6)
    plt.axis('off')
    
    stats_text = f"""
Road Extraction Statistics:

Original Image: {original_img.size[0]} × {original_img.size[1]}
Total Road Pixels: {road_data['total_pixels']:,}
Sampled Points: {len(sampled_pixels):,}
Coverage: {(road_data['total_pixels'] / (original_img.size[0] * original_img.size[1])) * 100:.2f}%

Patrol Route:
Total Points: {len(route_points)}
X Range: {min(pixel_x):.3f} - {max(pixel_x):.3f}
Y Range: {min(pixel_y):.3f} - {max(pixel_y):.3f}

Route Coverage:
X Range: {min(p['x'] for p in route_points):.3f} - {max(p['x'] for p in route_points):.3f}
Y Range: {min(p['y'] for p in route_points):.3f} - {max(p['y'] for p in route_points):.3f}
    """
    
    plt.text(0.05, 0.95, stats_text, transform=plt.gca().transAxes, 
             verticalalignment='top', fontfamily='monospace', fontsize=10)
    
    plt.title('Extraction Statistics')
    
    plt.tight_layout()
    plt.savefig('data/extraction_verification.png', dpi=150, bbox_inches='tight')
    plt.show()
    
    print("✓ Road extraction verification complete!")
    print("  Saved visualization: data/extraction_verification.png")
    
    # Check route quality
    route_x_range = max(p['x'] for p in route_points) - min(p['x'] for p in route_points)
    route_y_range = max(p['y'] for p in route_points) - min(p['y'] for p in route_points)
    
    print(f"\nRoute Quality Check:")
    print(f"  Route covers {route_x_range:.1%} of image width")
    print(f"  Route covers {route_y_range:.1%} of image height")
    
    if route_x_range > 0.3 and route_y_range > 0.3:
        print("  ✓ Good coverage - route spans a significant area")
    else:
        print("  ⚠ Limited coverage - route may be too concentrated")

if __name__ == "__main__":
    try:
        verify_extraction_results()
    except Exception as e:
        print(f"Error: {e}")
        import traceback
        traceback.print_exc()