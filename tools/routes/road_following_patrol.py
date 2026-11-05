#!/usr/bin/env python3
"""
Generate a patrol route that ACTUALLY FOLLOWS road geometry.

Instead of sampling random points, this:
1. Builds a graph from actual road intersections  
2. Finds a route that traverses road segments sequentially
3. Outputs the actual coordinate sequence ALONG each road line
4. The patrol car follows continuous road paths, not random jumps
"""

import json
import numpy as np
import geopandas as gpd
import networkx as nx
from shapely.geometry import LineString, Point, MultiLineString
from shapely.ops import split, snap, unary_union
from collections import defaultdict

def load_roads_as_graph(roads_file, bounds_file):
    """
    Build a road network graph from actual OSM road geometries.
    Nodes = intersections, Edges = road segments with geometry.
    """
    
    print("Loading road geometries...")
    roads_gdf = gpd.read_file(roads_file)
    
    if roads_gdf.crs != "EPSG:3857":
        roads_gdf = roads_gdf.to_crs("EPSG:3857")
    
    with open(bounds_file, 'r') as f:
        bounds = json.load(f)
    
    minx = bounds['minx']
    miny = bounds['miny']
    maxx = bounds['maxx']
    maxy = bounds['maxy']
    width = maxx - minx
    height = maxy - miny
    
    print(f"Loaded {len(roads_gdf)} road segments")
    print(f"Map bounds: x=[{minx:.0f}, {maxx:.0f}], y=[{miny:.0f}, {maxy:.0f}]")
    
    # Build a graph where each road endpoint/intersection is a node
    # and each road segment is an edge with its full geometry
    G = nx.Graph()
    
    # Tolerance for snapping nearby endpoints together (in meters, projected)
    SNAP_TOLERANCE = 15.0  # 15 meters
    
    # Collect all endpoints
    all_endpoints = []
    road_geometries = []
    
    for idx, road in roads_gdf.iterrows():
        geom = road.geometry
        if geom is None or geom.is_empty:
            continue
        
        lines = []
        if geom.geom_type == 'LineString':
            lines = [geom]
        elif geom.geom_type == 'MultiLineString':
            lines = list(geom.geoms)
        
        for line in lines:
            coords = list(line.coords)
            if len(coords) < 2:
                continue
            road_geometries.append(coords)
            all_endpoints.append(coords[0])
            all_endpoints.append(coords[-1])
    
    print(f"Found {len(road_geometries)} road line segments")
    print(f"Found {len(all_endpoints)} endpoints")
    
    # Cluster nearby endpoints into intersection nodes
    endpoint_to_node = {}
    node_positions = {}  # node_id -> (x, y)
    next_node_id = 0
    
    def find_or_create_node(x, y):
        nonlocal next_node_id
        
        # Check if there's an existing node nearby
        for nid, (nx_pos, ny_pos) in node_positions.items():
            dist = ((x - nx_pos)**2 + (y - ny_pos)**2)**0.5
            if dist < SNAP_TOLERANCE:
                return nid
        
        # Create new node
        nid = next_node_id
        next_node_id += 1
        node_positions[nid] = (x, y)
        return nid
    
    # Build graph edges from road segments
    edge_count = 0
    
    for coords in road_geometries:
        start = coords[0]
        end = coords[-1]
        
        start_node = find_or_create_node(start[0], start[1])
        end_node = find_or_create_node(end[0], end[1])
        
        if start_node == end_node:
            continue  # Skip self-loops
        
        # Normalize coordinates for this road segment
        normalized_coords = []
        for x, y in coords:
            norm_x = (x - minx) / width
            norm_y = 1.0 - (y - miny) / height  # Flip Y for image coords
            normalized_coords.append((norm_x, norm_y))
        
        # Calculate road segment length
        length = 0
        for i in range(len(coords) - 1):
            dx = coords[i+1][0] - coords[i][0]
            dy = coords[i+1][1] - coords[i][1]
            length += (dx**2 + dy**2)**0.5
        
        # Add edge with geometry
        if not G.has_edge(start_node, end_node):
            G.add_edge(start_node, end_node, 
                      geometry=normalized_coords,
                      length=length)
            edge_count += 1
    
    # Add node positions (normalized)
    for nid, (x, y) in node_positions.items():
        norm_x = (x - minx) / width
        norm_y = 1.0 - (y - miny) / height
        G.nodes[nid]['x'] = norm_x
        G.nodes[nid]['y'] = norm_y
    
    print(f"Built road graph: {G.number_of_nodes()} intersections, {edge_count} road segments")
    
    return G

def find_largest_component(G):
    """Get the largest connected component."""
    components = list(nx.connected_components(G))
    components.sort(key=len, reverse=True)
    print(f"Found {len(components)} connected components")
    print(f"Largest component: {len(components[0])} nodes")
    return G.subgraph(components[0]).copy()

def create_eulerian_patrol(G):
    """
    Create a patrol route that traverses every road segment.
    Uses Chinese Postman approach: find minimum weight edges to add
    to make graph Eulerian, then find Eulerian circuit.
    """
    
    print("Creating road-following patrol route...")
    
    # Find nodes with odd degree (need to be paired for Eulerian circuit)
    odd_nodes = [n for n in G.nodes() if G.degree(n) % 2 != 0]
    print(f"Nodes with odd degree: {len(odd_nodes)}")
    
    if len(odd_nodes) > 0:
        # For Chinese Postman: find minimum weight matching of odd nodes
        # and duplicate those edges. For simplicity, we'll use a DFS-based
        # approach that traverses all edges.
        print("Using DFS traversal to cover all road segments...")
        return dfs_all_edges(G)
    else:
        # Graph is already Eulerian - find Eulerian circuit
        print("Graph is Eulerian! Finding optimal circuit...")
        try:
            circuit = list(nx.eulerian_circuit(G))
            return circuit_to_points(G, circuit)
        except nx.NetworkXError:
            print("Eulerian circuit failed, falling back to DFS...")
            return dfs_all_edges(G)

def dfs_all_edges(G):
    """
    DFS-based traversal that visits every edge (road segment) at least once.
    Returns the full coordinate sequence along actual road geometry.
    """
    
    # Start from a node with high degree (likely a major intersection)
    start_node = max(G.nodes(), key=lambda n: G.degree(n))
    print(f"Starting DFS from node {start_node} (degree {G.degree(start_node)})")
    
    visited_edges = set()
    route_coords = []
    
    def dfs(node, depth=0):
        # Get all edges from this node, prefer unvisited ones
        edges = list(G.edges(node, data=True))
        
        # Sort: unvisited first, then by length (prefer shorter segments)
        unvisited = [(n, neighbor, data) for n, neighbor, data in edges 
                     if frozenset([n, neighbor]) not in visited_edges]
        visited = [(n, neighbor, data) for n, neighbor, data in edges 
                   if frozenset([n, neighbor]) in visited_edges]
        
        for n, neighbor, data in unvisited + visited:
            edge_key = frozenset([n, neighbor])
            
            if edge_key in visited_edges and len(unvisited) > 0:
                continue  # Skip already visited if there are unvisited edges
            
            if edge_key not in visited_edges:
                visited_edges.add(edge_key)
                
                # Add the actual road geometry coordinates
                geom = data.get('geometry', [])
                if geom:
                    # Determine direction: if we're going from start to end or reverse
                    first_coord = geom[0]
                    last_coord = geom[-1]
                    
                    node_x = G.nodes[node].get('x', 0)
                    node_y = G.nodes[node].get('y', 0)
                    
                    dist_to_first = ((first_coord[0] - node_x)**2 + (first_coord[1] - node_y)**2)**0.5
                    dist_to_last = ((last_coord[0] - node_x)**2 + (last_coord[1] - node_y)**2)**0.5
                    
                    if dist_to_first <= dist_to_last:
                        # Forward direction
                        route_coords.extend(geom)
                    else:
                        # Reverse direction
                        route_coords.extend(reversed(geom))
                
                dfs(neighbor, depth + 1)
                
                # After returning, check if there are more unvisited edges from current node
                remaining = [frozenset([node, nb]) for nb in G.neighbors(node) 
                           if frozenset([node, nb]) not in visited_edges]
                if remaining:
                    # Backtrack: add reverse geometry to get back
                    if geom:
                        node_x = G.nodes[node].get('x', 0)
                        node_y = G.nodes[node].get('y', 0)
                        first_coord = geom[0]
                        last_coord = geom[-1]
                        
                        dist_to_first = ((first_coord[0] - node_x)**2 + (first_coord[1] - node_y)**2)**0.5
                        dist_to_last = ((last_coord[0] - node_x)**2 + (last_coord[1] - node_y)**2)**0.5
                        
                        if dist_to_first <= dist_to_last:
                            route_coords.extend(reversed(geom))
                        else:
                            route_coords.extend(geom)
    
    dfs(start_node)
    
    print(f"DFS traversal complete:")
    print(f"  Visited {len(visited_edges)} out of {G.number_of_edges()} road segments")
    print(f"  Generated {len(route_coords)} coordinate points along roads")
    
    # Check coverage
    coverage = len(visited_edges) / G.number_of_edges() * 100 if G.number_of_edges() > 0 else 0
    print(f"  Road coverage: {coverage:.1f}%")
    
    return route_coords

def circuit_to_points(G, circuit):
    """Convert an Eulerian circuit to coordinate points."""
    
    route_coords = []
    
    for u, v in circuit:
        edge_data = G.get_edge_data(u, v)
        if edge_data:
            geom = edge_data.get('geometry', [])
            if geom:
                # Determine direction
                node_x = G.nodes[u].get('x', 0)
                node_y = G.nodes[u].get('y', 0)
                
                first_coord = geom[0]
                dist_to_first = ((first_coord[0] - node_x)**2 + (first_coord[1] - node_y)**2)**0.5
                
                last_coord = geom[-1]
                dist_to_last = ((last_coord[0] - node_x)**2 + (last_coord[1] - node_y)**2)**0.5
                
                if dist_to_first <= dist_to_last:
                    route_coords.extend(geom)
                else:
                    route_coords.extend(reversed(geom))
    
    return route_coords

def simplify_route(route_coords, max_points=2000):
    """
    Simplify route by removing redundant points while keeping road shape.
    """
    
    if len(route_coords) <= max_points:
        return route_coords
    
    # Sample every Nth point to stay within limit
    step = max(1, len(route_coords) // max_points)
    simplified = route_coords[::step]
    
    # Always include the last point
    if simplified[-1] != route_coords[-1]:
        simplified.append(route_coords[-1])
    
    print(f"Simplified route: {len(route_coords)} -> {len(simplified)} points")
    return simplified

def main():
    roads_file = "data/source/santacruz_roads.geojson"
    bounds_file = "assets/maps/map.bounds.json"
    output_file = "data/routes/citywide_patrol_route.json"
    
    print("="*60)
    print("ROAD-FOLLOWING PATROL ROUTE GENERATOR")
    print("="*60)
    
    # Step 1: Build road network graph
    G = load_roads_as_graph(roads_file, bounds_file)
    
    # Step 2: Use largest connected component
    G = find_largest_component(G)
    
    # Step 3: Create patrol route that follows actual road geometry
    route_coords = create_eulerian_patrol(G)
    
    if len(route_coords) < 10:
        print("ERROR: Not enough route points generated!")
        return
    
    # Step 4: Simplify if too many points (keep under 2000 for Godot performance)
    route_coords = simplify_route(route_coords, max_points=2000)
    
    # Step 5: Convert to output format
    patrol_points = []
    for coord in route_coords:
        patrol_points.append({
            "x": coord[0],
            "y": coord[1]
        })
    
    # Analyze coverage  
    x_coords = [p['x'] for p in patrol_points]
    y_coords = [p['y'] for p in patrol_points]
    
    # Step 6: Save
    route_data = {
        "route_info": {
            "total_points": len(patrol_points),
            "source": "road_geometry_traversal",
            "method": "dfs_edge_traversal_with_actual_geometry",
            "coverage_type": "follows_actual_road_lines"
        },
        "points": patrol_points
    }
    
    with open(output_file, 'w') as f:
        json.dump(route_data, f, indent=2)
    
    print(f"\n{'='*60}")
    print(f"PATROL ROUTE SAVED: {output_file}")
    print(f"{'='*60}")
    print(f"  Total points: {len(patrol_points)}")
    print(f"  X range: {min(x_coords):.3f} to {max(x_coords):.3f}")
    print(f"  Y range: {min(y_coords):.3f} to {max(y_coords):.3f}")
    print(f"  Method: Follows actual road geometry (not random points)")
    print(f"  Behavior: Car moves along road lines sequentially")

if __name__ == "__main__":
    import sys
    sys.setrecursionlimit(10000)
    
    try:
        main()
    except Exception as e:
        print(f"Error: {e}")
        import traceback
        traceback.print_exc()