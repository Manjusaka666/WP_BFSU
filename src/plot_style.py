#!/usr/bin/env python3
"""
Professional figure styling for academic journals
Configured for top economics journals (AER, REStud, QJE standards)
"""
import matplotlib.pyplot as plt
import matplotlib as mpl

def set_publication_style():
    """
    Set matplotlib to publication-quality style
    - Removes default blue background
    - Uses serif fonts (Times New Roman style)
    - Professional color palette
    - High DPI for crisp figures
    """
    # Reset to defaults first
    mpl.rcdefaults()
    
    # Font settings - Times New Roman for academic papers
    plt.rcParams['font.family'] = 'serif'
    plt.rcParams['font.serif'] = ['Times New Roman', 'DejaVu Serif', 'Bitstream Vera Serif']
    plt.rcParams['font.size'] = 10
    plt.rcParams['axes.labelsize'] = 11
    plt.rcParams['axes.titlesize'] = 12
    plt.rcParams['xtick.labelsize'] = 9
    plt.rcParams['ytick.labelsize'] = 9
    plt.rcParams['legend.fontsize'] = 9
    
    # Figure settings
    plt.rcParams['figure.figsize'] = (8, 5)
    plt.rcParams['figure.dpi'] = 100
    plt.rcParams['savefig.dpi'] = 300  # High DPI for publication
    plt.rcParams['savefig.bbox'] = 'tight'
    plt.rcParams['savefig.pad_inches'] = 0.1
    
    # Axes and grid - clean, minimal
    plt.rcParams['axes.linewidth'] = 0.8
    plt.rcParams['axes.edgecolor'] = 'black'
    plt.rcParams['axes.facecolor'] = 'white'  # WHITE background (not blue!)
    plt.rcParams['axes.grid'] = True
    plt.rcParams['grid.alpha'] = 0.3
    plt.rcParams['grid.linestyle'] = ':'
    plt.rcParams['grid.linewidth'] = 0.5
    
    # Remove top and right spines (cleaner look)
    plt.rcParams['axes.spines.top'] = False
    plt.rcParams['axes.spines.right'] = False
    
    # Line and marker settings
    plt.rcParams['lines.linewidth'] = 1.5
    plt.rcParams['lines.markersize'] = 4
    
    # Legend
    plt.rcParams['legend.frameon'] = False
    plt.rcParams['legend.loc'] = 'best'
    
    # Remove figure title (use LaTeX caption instead)
   plt.rcParams['axes.titley'] = 1.0  # If title needed, keep flush
    
# Professional color palette (AER style)
COLOR_MAIN = '#2E5090'  # Professional blue
COLOR_ACCENT = '#C8102E'  # Accent red
COLOR_FILL = '#7FA5D2'  # Light blue for fill
COLOR_GRAY = '#5A5A5A'  # Dark gray for reference lines
COLOR_GREEN = '#2F7F4F'  # Green for positive
COLOR_ORANGE = '#D47500'  # Orange for emphasis

def get_color_scheme():
    """Return professional color scheme"""
    return {
        'main': COLOR_MAIN,
        'accent': COLOR_ACCENT, 
        'fill': COLOR_FILL,
        'gray': COLOR_GRAY,
        'green': COLOR_GREEN,
        'orange': COLOR_ORANGE
    }
