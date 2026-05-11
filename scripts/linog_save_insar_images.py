import numpy as np
import matplotlib.pyplot as plt
import matplotlib.colors as mcolors
import isceobj
import sys
import os

# --- SETTINGS ---
# 1 = Full Resolution (Every pixel).
DOWNSAMPLE = 1  
OUTPUT_DPI = 600
# ----------------

def stretch_magnitude(mag, low_pct=1, high_pct=99):
    """
    Stretches the magnitude brightness to improve contrast.
    """
    valid_mag = mag[mag > 1e-6]
    if valid_mag.size == 0:
        return np.zeros_like(mag)

    p_low = np.percentile(valid_mag, low_pct)
    p_high = np.percentile(valid_mag, high_pct)

    # FIX B1: p_high == p_low is a scalar bool, NOT an array mask.
    # Using it as an index raises IndexError. Return early instead.
    if p_high == p_low:
        return np.zeros_like(mag)

    mag_clipped = np.clip(mag, p_low, p_high)
    mag_norm = (mag_clipped - p_low) / (p_high - p_low)

    return mag_norm

def save_images(filename):
    if not filename.endswith('.int'):
        print(f"Skipping {filename} (not an .int file)")
        return

    print(f"Processing {filename} (Phase + Combined, High Res)...")
    
    try:
        # 1. Load Metadata
        img = isceobj.createImage()
        img.load(filename + '.xml')
        width = img.width
        length = img.length
        
        # 2. Read Data (Full Resolution)
        data = np.memmap(filename, dtype=np.complex64, mode='r', shape=(length, width))
        
        # 3. FLIP DATA (Fix orientation so North is Up)
        # We flip the complex data array immediately
        data_flipped = np.flipud(data)
        
        # 4. Extract Components
        phase = np.angle(data_flipped)
        mag = np.abs(data_flipped)
        
    except Exception as e:
        print(f"Error reading {filename}: {e}")
        return

    # 5. Prepare Output Arrays
    
    # -- Magnitude processing (for the combined image brightness) --
    mag_norm = stretch_magnitude(mag)
    
    # -- Phase processing (for color) --
    # Normalize -pi to pi -> 0 to 1
    phase_norm = (phase + np.pi) / (2 * np.pi)

    # -- Combined Image (HSV -> RGB) --
    # Hue=Phase, Saturation=1, Value=Magnitude
    hsv_image = np.dstack((phase_norm, np.ones_like(phase), mag_norm))
    rgb_combined = mcolors.hsv_to_rgb(hsv_image)

    # 6. Calculate Figure Dimensions (1:1 Pixel Mapping)
    # We want the output JPEG to match the data shape exactly
    fig_height_in = phase.shape[0] / OUTPUT_DPI
    fig_width_in = phase.shape[1] / OUTPUT_DPI

    # --- SAVE 1: PHASE IMAGE ---
    fig = plt.figure(figsize=(fig_width_in, fig_height_in))
    ax = plt.axes([0, 0, 1, 1])
    ax.set_axis_off()
    ax.imshow(phase, cmap='jet', aspect='auto', interpolation='nearest')
    
    out_name_phase = filename.replace('.int', '_phase.jpg')
    plt.savefig(out_name_phase, dpi=OUTPUT_DPI)
    plt.close(fig)
    print(f"   Saved {out_name_phase}")

    # --- SAVE 2: COMBINED IMAGE ---
    fig = plt.figure(figsize=(fig_width_in, fig_height_in))
    ax = plt.axes([0, 0, 1, 1])
    ax.set_axis_off()
    ax.imshow(rgb_combined, aspect='auto', interpolation='nearest')
    
    out_name_comb = filename.replace('.int', '_combined.jpg')
    plt.savefig(out_name_comb, dpi=OUTPUT_DPI)
    plt.close(fig)
    print(f"   Saved {out_name_comb}")

if __name__ == "__main__":
    files = sys.argv[1:]
    if not files:
        # Auto-find files if none provided
        files = [f for f in os.listdir('.') if f.startswith('filt') and f.endswith('.int')]
        if not files:
            # FIX B5: usage string now matches actual filename (linog_ prefix)
            print("Usage: python linog_save_insar_images.py file1.int ...")
            sys.exit(1)
    
    for f in sorted(files):
        save_images(f)
