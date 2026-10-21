"""Run from any directory: python scripts/run.py. Requires iverilog and vvp on PATH."""
import hashlib
import os
from pathlib import Path
import random
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
os.chdir(ROOT)
(ROOT / 'work').mkdir(exist_ok=True)
LOG = []

def note(s):
    print(s, flush=True)
    LOG.append(s)

def run(args):
    note('$ ' + ' '.join(map(str, args)))
    p = subprocess.run(list(map(str, args)), text=True, capture_output=True)
    note(p.stdout + p.stderr)
    if p.returncode or 'Fatal:' in p.stdout or 'FATAL:' in p.stdout or 'ERROR:' in p.stdout:
        raise RuntimeError(f'command failed: {p.returncode}')

def wrap(v, w=32):
    v &= (1 << w) - 1
    return v - (1 << w) if v >> (w - 1) else v

class PID:
    def __init__(self):
        self.p = self.i = self.ip = self.d = self.ep = 0

    def step(self, reset, sp, fb, kp, ki, kd):
        if reset:
            self.__init__()
            return 0
        e = wrap(sp - fb, 16)
        out = max(-100000, min(100000, wrap(self.p + self.i + self.d)))
        p = wrap(kp * e)
        i = wrap(self.ip + (wrap(ki * e) >> 4))
        d = wrap(kd * wrap(e - self.ep)) >> 2
        self.p, self.ip, self.i, self.d, self.ep = p, self.i, i, d, e
        return out

def pid_vectors():
    rng = random.Random(20261019)
    models = [PID() for _ in range(4)]
    rows, expected = [], []
    fb = [400, -250, 600, -300]
    old_out = [0] * 4
    for t in range(22000):
        for axis in range(4):
            reset = int(t in (0, 501, 1800, 21999))
            if t <= 500:
                sp, feedback, kp, ki, kd = 0, fb[axis], 4, 0, 2
            elif t < 600:
                sp, feedback, kp, ki, kd = 0, 0, 4, 3, 2
            elif t < 700:
                sp, feedback, kp, ki, kd = (32767, -32768, -127, 127, -128) if axis % 2 else (-32768, 32767, 127, -128, 127)
            elif t < 1800:
                sp, feedback = rng.randrange(-32768, 32768), rng.randrange(-32768, 32768)
                kp, ki, kd = [rng.randrange(-128, 128) for _ in range(3)]
            else:
                # Integral crosses 32-bit wrap after long saturation; alternating signs across axes.
                sp, feedback, kp, ki, kd = (32767 if axis % 2 else -32768), 0, 127, 127, 127
            row = (reset, sp, feedback, kp, ki, kd)
            rows.append(' '.join(map(str, row)))
            y = models[axis].step(*row)
            expected.append(y & 0xffffffff)
            if 0 < t <= 500:
                fb[axis] = max(-1000, min(1000, fb[axis] - (old_out[axis] >> 10) - (fb[axis] >> 4)))
            old_out[axis] = y
    Path('golden/stimulus.txt').write_text('\n'.join(rows) + '\n')
    return expected

def mac_vectors(w, aw, filename):
    rng = random.Random(w * 1000 + aw)
    mask, amask = (1 << w) - 1, (1 << aw) - 1
    acc = 0
    rows = []
    ew = max(2 * (w + 1), aw) + 2
    def emit(op, a=0, b=0, load=0, mode=1, shift=0):
        nonlocal acc
        a, b, load = a & mask, b & mask, load & amask
        if op == 1:
            acc = 0
        elif op == 2:
            acc = load
        elif op == 0:
            product = (wrap(a, w) * wrap(b, w)) if mode & 1 else a * b
            if mode & 4 and 0 < shift < ew:
                product += 1 << (shift - 1)
            total = (wrap(acc, aw) if mode & 1 else acc) + (product >> shift)
            if mode & 2:
                lo, hi = (-(1 << (aw - 1)), (1 << (aw - 1)) - 1) if mode & 1 else (0, amask)
                total = max(lo, min(hi, total))
            acc = total & amask
        rows.append(f'{op} {a:x} {b:x} {load:x} {mode} {shift} {acc:x}')
    for mode in range(8):
        for a in (0, 1, -1, (1 << (w - 1)), (1 << (w - 1)) - 1):
            for b in (0, 1, -1, (1 << (w - 1)), (1 << (w - 1)) - 1):
                for sh in (0, 1, 4, w, ew - 1, ew, 255):
                    emit(2, load=amask >> 1)
                    emit(0, a, b, mode=mode, shift=sh)
    for _ in range(5000):
        emit(rng.choices([0, 1, 2, 3], [85, 4, 10, 1])[0], rng.getrandbits(w), rng.getrandbits(w), rng.getrandbits(aw), rng.randrange(8), rng.choice([0, 1, 2, 4, 8, 31, 63, 255]))
    # Dot products, then sliding FIR windows: independent Python convolution sums.
    for _ in range(50):
        emit(1)
        for _ in range(16):
            emit(0, rng.randrange(-32, 32), rng.randrange(-32, 32))
    signal = [rng.randrange(-20, 20) for _ in range(80)]
    taps = [3, -2, 7, 1, -4]
    for end in range(len(taps), len(signal) + 1):
        emit(1)
        for a, b in zip(signal[end-len(taps):end], taps):
            emit(0, a, b)
        assert wrap(acc, aw) == sum(a*b for a,b in zip(signal[end-len(taps):end], taps))
    Path(filename).write_text('\n'.join(rows) + '\n')

def sim(top, sources, extra=(), plus=()):
    if '--ivl-direct' in sys.argv:
        # Workaround for this host's crashing Windows iverilog launcher.
        # These sources use no includes/macros; concatenate with source locations.
        # ivl is the same Icarus compiler backend invoked by iverilog.
        lib = Path(os.environ.get('IVL_DIR', 'D:/iverilog/lib/ivl')).resolve()
        out = Path('work') / (top + '.vvp')
        source = Path('work') / (top + '_combined.sv')
        source.write_text('\n'.join(f'`line 1 "{s}" 0\n'+Path(s).read_text(encoding='utf-8') for s in sources), encoding='utf-8')
        conf = Path('work') / (top + '.conf')
        config = [f'root:{top}', f'basedir:{lib.as_posix()}', f'out:{out.as_posix()}',
                  'generation:2012', 'generation:no-specify', 'generation:assertions',
                  'generation:xtypes', 'generation:io-range-error',
                  'generation:no-strict-expr-width', 'generation:icarus-misc',
                  'warnings:n', 'iwidth:32', 'widthcap:65536']
        config += [f'module:{(lib/(m+".vpi")).as_posix()}' for m in ['system','v2005_math','va_math','v2009']]
        config += ['defparam:'+arg[2:] for arg in extra]
        conf.write_text('\n'.join(config)+'\n')
        run([lib/'ivl.exe', '-C', conf, '-C', lib/'vvp.conf', '--', source])
        run(['vvp', out, *plus])
        return
    if '--xsim' in sys.argv:
        bindir = Path(os.environ['VIVADO_BIN'])
        run([bindir/'xvlog.bat', '--sv', *sources])
        params = []
        for arg in extra:
            params += ['--generic_top', arg.split('.',1)[1]]
        run([bindir/'xelab.bat', top, '-s', top+'_snap', '--timescale', '1ns/1ps', *params])
        pargs = []
        for arg in plus:
            pargs += ['--testplusarg', arg.lstrip('+')]
        run([bindir/'xsim.bat', top+'_snap', '--runall', *pargs])
        return
    out = Path('work') / (top + ('_' + str(extra[-1]) if extra else '') + '.vvp')
    run(['iverilog', '-g2012', '-Wall', '-s', top, *extra, '-o', out, *sources])
    run(['vvp', out, *plus])

def main():
    if '--xsim' not in sys.argv and (not shutil.which('iverilog') or not shutil.which('vvp')):
        raise RuntimeError('Install Icarus Verilog and put iverilog/vvp on PATH')
    expected = pid_vectors()
    sim('tb_golden', ['reference/pid_main.v', 'tb/tb_golden.sv'])
    got = [int(s, 16) for s in Path('golden/original.txt').read_text().split()]
    if got != expected:
        bad = next((i for i, (a, b) in enumerate(zip(got, expected)) if a != b), min(len(got), len(expected)))
        raise AssertionError(f'Python/original PID mismatch at {bad}')
    note(f'PASS independent Python PID model: {len(got)} original RTL outputs')
    for w, aw in [(32, 32), (8, 24), (16, 64)]:
        name = f'golden/mac_{w}_{aw}.txt'
        mac_vectors(w, aw, name)
        sim('tb_mac', ['rtl/mac_core.sv', 'tb/tb_mac.sv'], [f'-Ptb_mac.W={w}', f'-Ptb_mac.AW={aw}'], [f'+VECTORS={name}'])
    sim('tb_pid_mac', ['rtl/mac_core.sv', 'rtl/mac_regs.sv', 'tb/tb_pid_mac.sv'])
    sim('tb_regs', ['rtl/mac_core.sv', 'rtl/mac_regs.sv', 'tb/tb_regs.sv'])
    sim('tb_top_4pid', ['reference/pid_main.v', 'reference/pwm.v', 'tb/legacy_top.sv', 'reference/new_sim.v'])
    note('PASS ALL REGRESSIONS (legacy monitor-only test also ran; see self-checking tests above)')

if __name__ == '__main__':
    try:
        main()
    except Exception as exc:
        note('FAIL: ' + str(exc))
        sys.exit(1)
    finally:
        Path('docs/test_log.txt').write_text('\n'.join(LOG))
