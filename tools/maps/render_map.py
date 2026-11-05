#!/usr/bin/env python3
# tools/render_map.py
import argparse
import json
from pathlib import Path

import contextily as ctx
import geopandas as gpd
import matplotlib.pyplot as plt
from pyproj import Transformer


FRIENDLY_BG = "#DFF4FF"
ROAD_OUTER = "#FFF0B8"
ROAD_INNER = "#FF8F6B"
ROAD_ACCENT = "#4DB6AC"

def main():
    p = argparse.ArgumentParser()
    p.add_argument("--roads", default="data/source/santacruz_roads.geojson")
    p.add_argument("--bbox", default="data/source/santacruz_bbox.json")
    p.add_argument("--out", default="assets/maps/map.png")
    p.add_argument("--width", type=int, default=2048)
    p.add_argument("--height", type=int, default=2048)
    p.add_argument("--outer-width", type=float, default=8.0)
    p.add_argument("--inner-width", type=float, default=4.4)
    args = p.parse_args()

    roads = gpd.read_file(args.roads)
    meta = json.load(open(args.bbox, "r", encoding="utf-8"))
    bounds = meta.get("bounds")
    if isinstance(bounds[0], (list, tuple)):
        minlon, minlat, maxlon, maxlat = bounds[0]
    else:
        minlon, minlat, maxlon, maxlat = bounds

    roads_proj = roads.to_crs(epsg=3857)
    transformer = Transformer.from_crs("EPSG:4326", "EPSG:3857", always_xy=True)
    minx, miny = transformer.transform(minlon, minlat)
    maxx, maxy = transformer.transform(maxlon, maxlat)

    # Add padding to improve centering
    padding = max(maxx - minx, maxy - miny) * 0.1
    minx -= padding
    maxx += padding
    miny -= padding
    maxy += padding

    dpi = 100
    fig, ax = plt.subplots(figsize=(args.width/dpi, args.height/dpi), dpi=dpi)

    fig.patch.set_facecolor(FRIENDLY_BG)
    ax.set_facecolor(FRIENDLY_BG)

    # A light basemap keeps the prototype readable for kids while still feeling map-like.
    try:
        ctx.add_basemap(
            ax,
            source=ctx.providers.CartoDB.PositronNoLabels,
            crs=roads_proj.crs,
            attribution=False,
            zoom=16,
        )
    except Exception as exc:
        print(f"Basemap unavailable, using flat background instead: {exc}")

    # Thick, soft double-stroke roads make the prototype friendlier and easier to read.
    roads_proj.plot(ax=ax, linewidth=args.outer_width + 2.0, color="#FFFFFF", alpha=0.15)
    roads_proj.plot(
        ax=ax,
        linewidth=args.outer_width,
        color=ROAD_OUTER,
        alpha=0.98,
    )
    roads_proj.plot(
        ax=ax,
        linewidth=args.inner_width,
        color=ROAD_INNER,
        alpha=0.96,
    )
    roads_proj.plot(
        ax=ax,
        linewidth=max(1.1, args.inner_width * 0.18),
        color=ROAD_ACCENT,
        alpha=0.45,
    )
    
    ax.set_xlim(minx, maxx)
    ax.set_ylim(miny, maxy)
    ax.axis("off")
    plt.subplots_adjust(left=0, right=1, top=1, bottom=0)
    fig.savefig(args.out, dpi=dpi, bbox_inches="tight", pad_inches=0, facecolor=fig.get_facecolor())
    
    # Save the actual bounds used for rendering
    actual_bounds = {"minx": minx, "miny": miny, "maxx": maxx, "maxy": maxy}
    bounds_file = Path(args.out).with_suffix(".bounds.json")
    with open(bounds_file, "w") as f:
        json.dump(actual_bounds, f, indent=2)
    print("Wrote", args.out)

if __name__ == "__main__":
    main()