from pathlib import Path
import shutil

import numpy as np
from PIL import Image, ImageOps


def read_digit(filename):
    # Keep one digit's shape while fitting it into the 8x8 training format.
    with Image.open(filename) as source:
        rgba = ImageOps.exif_transpose(source).convert("RGBA")
    paper = Image.new("RGBA", rgba.size, "white")
    paper.alpha_composite(rgba)
    gray = paper.convert("L")
    border = np.asarray(gray)
    if np.median(np.concatenate([border[0], border[-1], border[:, 0], border[:, -1]])) > 127:
        gray = ImageOps.invert(gray)
    gray = ImageOps.autocontrast(gray)
    bounds = gray.point(lambda value: 255 if value > 40 else 0).getbbox()
    if bounds is None:
        raise ValueError("No digit found. Use one dark digit on a plain white background.")
    digit = ImageOps.contain(gray.crop(bounds), (8, 8), Image.Resampling.LANCZOS)
    canvas = Image.new("L", (8, 8))
    canvas.paste(digit, ((8 - digit.width) // 2, (8 - digit.height) // 2))
    return np.rint(np.asarray(canvas, dtype=float) * 16 / 255).astype(int)


def show_result(pixels, folder):
    import matplotlib.pyplot as plt

    scores = np.loadtxt(folder / "rtl_scores.txt", dtype=int)
    prediction = int(np.argmax(scores))
    fig, (picture, chart) = plt.subplots(1, 2, figsize=(8, 3.4),
                                         gridspec_kw={"width_ratios": [1, 2]})
    picture.imshow(pixels.reshape(8, 8), cmap="gray", vmin=0, vmax=16,
                   interpolation="nearest")
    picture.set_title("Input to the MAC")
    picture.axis("off")
    colors = ["#146757" if i == prediction else "#9cafbf" for i in range(10)]
    chart.bar(range(10), scores, color=colors)
    chart.axhline(0, color="#485360", linewidth=0.7)
    chart.set_xticks(range(10))
    chart.set_xlabel("Digit")
    chart.set_ylabel("Integer score")
    chart.set_title(f"Highest score: {prediction}")
    fig.tight_layout()
    fig.savefig("digit_result.png", dpi=150)
    plt.close(fig)
    shutil.copyfile(folder / "digit.vcd", "digit.vcd")
    print(f"MAC prediction: {prediction}. Chart and waveform saved in {Path.cwd()}")
