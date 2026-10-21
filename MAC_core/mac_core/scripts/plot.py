"""Optional: plot actual regression data. Requires matplotlib."""
import csv
from pathlib import Path
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

root = Path(__file__).resolve().parents[1]
rows = list(csv.DictReader((root/'golden/closed_loop.csv').open()))
fig, axes = plt.subplots(2, 1, figsize=(10, 7), sharex=True, layout='constrained')
for axis, name in enumerate(['Roll', 'Pitch', 'Yaw', 'Z']):
    data = [r for r in rows if int(r['axis']) == axis]
    x = [int(r['sample']) for r in data]
    axes[0].plot(x, [int(r['feedback']) for r in data], label=name)
    axes[1].plot(x, [int(r['mac_output'])-int(r['original_output']) for r in data], label=name)
axes[0].set(ylabel='Feedback (integer units)', title='Original plant replay using shared-MAC outputs')
axes[0].legend(ncol=4)
axes[1].set(xlabel='Logical PID sample (not physical MAC clock)', ylabel='MAC minus original', ylim=(-1, 1), title='Bit-for-bit output difference: zero for every plotted sample')
for ax in axes:
    ax.grid(alpha=.25)
fig.savefig(root/'docs/closed_loop.png', dpi=150)
