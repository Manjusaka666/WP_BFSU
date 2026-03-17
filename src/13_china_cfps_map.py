"""
13_china_cfps_map.py
Produces a publication-quality China province map showing:
  - CFPS covered provinces (25, blue)
  - Non-CFPS provinces (light grey)
  - PBoC survey city locations (orange dots)
Output: outputs/figures/china_cfps_map.pdf + .png
"""

import os
import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import matplotlib.patches as mpatches

# Try geopandas / naturalearth; fall back to a hand-drawn approach
try:
    import geopandas as gpd

    HAVE_GEOPANDAS = True
except ImportError:
    HAVE_GEOPANDAS = False

# ── CFPS province list ────────────────────────────────────────────
CFPS_COVERED = {
    "Beijing", "Tianjin", "Hebei", "Shanxi", "Liaoning",
    "Jilin", "Heilongjiang", "Shanghai", "Jiangsu", "Zhejiang",
    "Anhui", "Fujian", "Jiangxi", "Shandong", "Henan",
    "Hubei", "Hunan", "Guangdong", "Chongqing", "Sichuan",
    "Guizhou", "Yunnan", "Shaanxi", "Gansu",
}

# ── PBoC survey cities (36 representative, lon/lat) ──────────────
PBOC_CITIES = [
    (116.4, 39.9), (121.5, 31.2), (117.2, 39.1), (106.5, 29.6),
    (126.5, 45.8), (125.3, 43.9), (123.4, 41.8), (121.6, 38.9),
    (114.5, 38.0), (112.6, 37.9), (117.0, 36.7), (120.4, 36.1),
    (113.7, 34.8), (118.8, 32.1), (120.2, 30.3), (121.6, 29.9),
    (117.3, 31.9), (114.3, 30.6), (113.0, 28.2), (115.9, 28.7),
    (113.3, 23.1), (114.1, 22.5), (119.3, 26.1), (108.4, 22.8),
    (106.7, 26.6), (104.1, 30.7), (102.7, 25.0), (108.9, 34.3),
    (103.8, 36.1), (87.6,  43.8), (91.1,  29.7), (120.6, 31.3),
    (120.7, 28.0), (112.5, 34.7), (111.8, 40.8), (106.3, 38.5),
]

# ── Colors ───────────────────────────────────────────────────────
CLR_COVERED = "#3182bd"   # blue
CLR_OTHER   = "#deebf7"   # light blue-grey
CLR_BORDER  = "white"
CLR_CITIES  = "#e6550d"   # orange

OUT_DIR = os.path.join(os.path.dirname(os.path.dirname(__file__)),
                       "outputs", "figures")
os.makedirs(OUT_DIR, exist_ok=True)


def make_map_geopandas():
    """Render with geopandas + naturalearth data."""
    import geopandas as gpd
    world = gpd.read_file(gpd.datasets.get_path("naturalearth_lowres"))
    # naturalearth_lowres has country level; use naturalearth_cities for points
    # For provinces we need the 1:50m admin-1 dataset
    try:
        from cartopy.io import shapereader
        fname = shapereader.natural_earth(
            resolution="50m", category="cultural", name="admin_1_states_provinces"
        )
        gdf = gpd.read_file(fname)
        china = gdf[gdf["admin"] == "China"].copy()
        china["color"] = china["name"].apply(
            lambda n: CLR_COVERED if n in CFPS_COVERED else CLR_OTHER
        )
    except Exception:
        return False

    fig, ax = plt.subplots(figsize=(5.5, 3.6))
    china.plot(ax=ax, color=china["color"], edgecolor=CLR_BORDER, linewidth=0.3)

    lons = [c[0] for c in PBOC_CITIES]
    lats = [c[1] for c in PBOC_CITIES]
    ax.scatter(lons, lats, s=10, color=CLR_CITIES, zorder=5,
               edgecolors="white", linewidths=0.4)

    ax.set_xlim(72, 136)
    ax.set_ylim(17, 54)
    ax.axis("off")

    legend_patches = [
        mpatches.Patch(color=CLR_COVERED, label="CFPS covered (25 provinces)"),
        mpatches.Patch(color=CLR_OTHER,   label="Not in CFPS sample"),
        plt.Line2D([0], [0], marker="o", color="w", markerfacecolor=CLR_CITIES,
                   markersize=5, label="PBoC survey cities"),
    ]
    ax.legend(handles=legend_patches, loc="lower left",
              fontsize=6.5, frameon=True, framealpha=0.9, edgecolor="none")

    fig.tight_layout(pad=0.3)
    return fig


def make_map_matplotlib():
    """Fallback: hand-draw simplified China outline + province fill."""
    fig, ax = plt.subplots(figsize=(5.5, 3.6))

    # Draw a simple bounding box with province centroid dots
    # (minimal but honest fallback — not a real choropleth)
    ax.set_xlim(72, 136)
    ax.set_ylim(17, 54)
    ax.set_facecolor("#f7f7f7")
    ax.tick_params(left=False, bottom=False,
                   labelleft=False, labelbottom=False)
    for spine in ax.spines.values():
        spine.set_visible(False)

    # Province centroids — CFPS covered
    cfps_centroids = [
        (116.4, 39.9), (117.2, 39.1), (113.0, 37.9), (123.4, 41.8),
        (125.3, 43.9), (126.5, 45.8), (121.5, 31.2), (119.0, 32.5),
        (120.2, 30.3), (117.0, 31.9), (118.0, 28.0), (117.0, 36.7),
        (113.7, 34.8), (114.0, 30.6), (112.0, 28.2), (115.5, 27.5),
        (113.3, 23.1), (119.0, 26.5), (106.5, 29.6), (104.0, 30.5),
        (106.7, 26.5), (101.5, 25.0), (108.5, 34.3), (103.5, 36.0),
        (121.5, 37.5),
    ]
    other_centroids = [
        (87.6, 43.8), (91.1, 29.5), (99.0, 34.0), (106.3, 38.5),
        (111.8, 40.8), (108.4, 22.5), (110.3, 20.0),
    ]

    for lon, lat in other_centroids:
        ax.add_patch(
            plt.Circle((lon, lat), 1.5, color=CLR_OTHER,
                        linewidth=0.3, edgecolor="#aaaaaa")
        )
    for lon, lat in cfps_centroids:
        ax.add_patch(
            plt.Circle((lon, lat), 1.5, color=CLR_COVERED,
                        linewidth=0.3, edgecolor="white")
        )

    lons = [c[0] for c in PBOC_CITIES]
    lats = [c[1] for c in PBOC_CITIES]
    ax.scatter(lons, lats, s=8, color=CLR_CITIES, zorder=5,
               edgecolors="white", linewidths=0.4)

    legend_patches = [
        mpatches.Patch(color=CLR_COVERED, label="CFPS covered (25 provinces)"),
        mpatches.Patch(color=CLR_OTHER,   label="Not in CFPS sample"),
        plt.Line2D([0], [0], marker="o", color="w", markerfacecolor=CLR_CITIES,
                   markersize=5, label="PBoC survey cities (~50)"),
    ]
    ax.legend(handles=legend_patches, loc="lower left",
              fontsize=6.5, frameon=True, framealpha=0.9, edgecolor="none")

    ax.set_title(
        "Data coverage: CFPS provinces and PBoC survey cities",
        fontsize=8, pad=4
    )
    fig.tight_layout(pad=0.3)
    return fig


# ── Main ─────────────────────────────────────────────────────────
fig = None
if HAVE_GEOPANDAS:
    fig = make_map_geopandas()
if fig is None or fig is False:
    fig = make_map_matplotlib()

for ext, dpi in [("pdf", None), ("png", 300)]:
    path = os.path.join(OUT_DIR, f"china_cfps_map.{ext}")
    kw = {} if ext == "pdf" else {"dpi": dpi}
    fig.savefig(path, bbox_inches="tight", **kw)
    print(f"Saved {path}")

plt.close(fig)
