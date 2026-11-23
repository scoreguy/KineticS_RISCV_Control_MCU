"""Train a linear digit classifier and check its scores on the Verilog MAC."""
import os
import argparse
import shutil
import subprocess
import tempfile
from pathlib import Path

import numpy as np
from sklearn.datasets import load_digits
from sklearn.linear_model import LogisticRegression
from sklearn.model_selection import train_test_split


def compile_testbench(folder, lanes=1):
    here = Path(__file__).resolve().parent
    core = here.parent / "rtl" / "mac_core.sv"
    sources = [core, here.parent / "rtl" / "dual_mac.sv", here / "tb_classifier.sv"]
    executable = f"sim{lanes}.vvp"
    # This Windows installation uses the Icarus compiler backend directly.
    compiler = shutil.which("iverilog")
    if not compiler:
        raise RuntimeError("Install Icarus Verilog and add its bin folder to PATH.")
    library = Path(compiler).resolve().parents[1] / "lib" / "ivl"
    if os.name == "nt" and (library / "ivl.exe").is_file():
        (folder / "source.sv").write_bytes(b"\n".join(path.read_bytes() for path in sources))
        settings = ["root:tb_classifier", "generation:2012", f"out:{executable}",
                    f"defparam:tb_classifier.LANES={lanes}",
                    f"basedir:{library.as_posix()}",
                    f"module:{(library / 'system.vpi').as_posix()}"]
        (folder / "compiler.conf").write_text("\n".join(settings) + "\n")
        command = [library / "ivl.exe", "-C", "compiler.conf", "-C",
                   library / "vvp.conf", "--", "source.sv"]
    else:
        command = [compiler, "-g2012", "-s", "tb_classifier",
                   f"-Ptb_classifier.LANES={lanes}", "-o", executable, *sources]
    subprocess.run(command, cwd=folder, check=True)


def save_memory(folder, name, values):
    # Verilog reads signed integers as 32-bit two's-complement hex words.
    np.savetxt(folder / name, values.ravel().astype(np.uint32), fmt="%08x")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--demo", nargs="?", const="", metavar="IMAGE",
                        help="show one digit from the test set or an image file")
    parser.add_argument("--demo-lanes", type=int, choices=(1, 2), default=1,
                        help="number of MACs for the single-image demo")
    args = parser.parse_args()
    pixels, labels = load_digits(return_X_y=True)
    train, test, train_labels, test_labels = train_test_split(
        pixels.astype(int), labels, test_size=0.2, stratify=labels, random_state=42)
    model = LogisticRegression(max_iter=2000)
    model.fit(train, train_labels)
    if args.demo is not None:
        from digit_demo import read_digit, show_result
        if args.demo:
            test = read_digit(args.demo).reshape(1, 64)
        else:
            print(f"Dataset label: {test_labels[0]}")
            test = test[:1]
        print("Running one image on the simulated MAC.", flush=True)
    else:
        correct = np.count_nonzero(model.predict(test) == test_labels)
        print(f"Training images: {len(train)}. Float correct: {correct}/{len(test)}", flush=True)

    with tempfile.TemporaryDirectory() as temp:
        folder = Path(temp)
        lane_counts = (1, 2) if args.demo is None else (args.demo_lanes,)
        for lanes in lane_counts:
            compile_testbench(folder, lanes)
        save_memory(folder, "pixels.hex", test)
        for bits in (8, 4):
            scale = (2 ** (bits - 1) - 1) / np.max(np.abs(model.coef_))
            weights = np.rint(model.coef_ * scale).astype(np.int64)
            bias = np.rint(model.intercept_ * scale).astype(np.int64)
            scores = test @ weights.T + bias
            save_memory(folder, "weights.hex", weights)
            save_memory(folder, "bias.hex", bias)
            save_memory(folder, "scores.hex", scores)
            if args.demo is not None:
                subprocess.run(["vvp", f"sim{args.demo_lanes}.vvp", "+demo"], cwd=folder, check=True)
                show_result(test, folder)
                return
            correct = np.count_nonzero(scores.argmax(axis=1) == test_labels)
            print(f"{bits}-bit weights: {correct}/{len(test)} correct", flush=True)
            for lanes in lane_counts:
                subprocess.run(["vvp", f"sim{lanes}.vvp"], cwd=folder, check=True)


if __name__ == "__main__":
    main()
