#!/usr/bin/env python3
"""
LInOG Interferogram Report Grid Generator
Generates US Letter landscape report pages showing phase + combined images.

Usage:
    python linog_create_grid.py --path 448 --frame 0310
    python linog_create_grid.py  # defaults to PATH=448, FRAME=0000
"""

import matplotlib
matplotlib.use('Agg')  # Non-interactive backend
import matplotlib.pyplot as plt
import matplotlib.image as mpimg
import math
import glob
import os
import argparse

# --- SETTINGS ---
FIG_WIDTH = 11       # US Letter Landscape
FIG_HEIGHT = 8.5
DPI = 300
ROWS = 3
COLS_TOTAL = 11
WIDTH_RATIOS = [1, 1, 0.4, 1, 1, 0.4, 1, 1, 0.4, 1, 1]
# ----------------

def create_grid(date_list, page_num, path_num, frame_num, frame_tag):
    fig, axes = plt.subplots(ROWS, COLS_TOTAL,
                             figsize=(FIG_WIDTH, FIG_HEIGHT),
                             gridspec_kw={'width_ratios': WIDTH_RATIOS})

    fig.suptitle(f"Path {path_num} Frame {frame_num} - Page {page_num}",
                 fontsize=14, weight='bold', y=0.96)

    for ax in axes.flatten():
        ax.axis('off')

    for i, date_string in enumerate(date_list):
        if i >= 12:
            break

        row = i // 4
        pair_index_in_row = i % 4
        col_start = pair_index_in_row * 3

        ax_phase = axes[row, col_start]
        ax_comb  = axes[row, col_start + 1]

        phase_file = f"filt_{date_string}_phase.jpg"
        comb_file = f"filt_{date_string}_combined.jpg"

        if os.path.exists(phase_file) and os.path.exists(comb_file):
            img_p = mpimg.imread(phase_file)
            ax_phase.imshow(img_p)
            ax_phase.set_title(f"{date_string}\n(Phase)", fontsize=5, weight='bold')
            ax_phase.axis('off')

            img_c = mpimg.imread(comb_file)
            ax_comb.imshow(img_c)
            ax_comb.set_title(f"{date_string}\n(Combined)", fontsize=5, weight='bold')
            ax_comb.axis('off')
        else:
            print(f"Warning: Missing files for {date_string}")

    plt.subplots_adjust(left=0.05, right=0.95, top=0.90, bottom=0.05,
                        wspace=0.05, hspace=0.25)

    output_filename = f"{frame_tag}_Igram_Report_Page_{page_num}.jpg"
    print(f"Saving {output_filename} ({FIG_WIDTH}x{FIG_HEIGHT} inches)...")
    plt.savefig(output_filename, dpi=DPI, bbox_inches='tight')
    plt.close()
    return output_filename


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="LInOG Interferogram Report Grid Generator")
    parser.add_argument("--path", default="448",
                        help="ALOS Path number (e.g., 448)")
    parser.add_argument("--frame", default="0000",
                        help="ALOS Frame number (e.g., 0310)")
    args = parser.parse_args()

    frame_tag = f"P{args.path}F{args.frame}"

    phase_files = sorted(glob.glob("*_phase.jpg"))

    if not phase_files:
        print("No images found. Run linog_save_insar_images.py first.")
    else:
        unique_dates = [p.replace("filt_", "").replace("_phase.jpg", "")
                        for p in phase_files]
        print(f"Found {len(unique_dates)} date pairs.")

        dates_per_page = 12
        total_pages = math.ceil(len(unique_dates) / dates_per_page)

        for page in range(total_pages):
            start = page * dates_per_page
            end = start + dates_per_page
            create_grid(unique_dates[start:end], page + 1,
                        args.path, args.frame, frame_tag)

        print("Done!")