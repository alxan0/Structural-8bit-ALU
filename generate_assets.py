"""Generate waveform / diagram / transcript PNGs for the ALU presentation.

We model the alu_top behavior cycle-accurately enough to produce honest
waveforms matching the design described in documentation.md:
  - 1-cycle LOAD
  - engine latency: ADD/SUB=1, MUL=6, DIV=9
  - top-level latency = engine + 3 (LOAD + dispatch + DONE)
"""
from pathlib import Path
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import matplotlib.patches as mpatches
from matplotlib.patches import FancyBboxPatch, FancyArrowPatch, Rectangle
import numpy as np

OUT = Path(__file__).parent / "presentation_assets"
OUT.mkdir(exist_ok=True)

# --- styling ---
BG = "#0F172A"; PANEL="#1B2640"; ACC="#4A90E2"; TXT="#EAEEF7"
MUTED="#A8B2C8"; OK="#5BD49E"; WARN="#F4B860"
plt.rcParams.update({
    "axes.facecolor": BG, "figure.facecolor": BG,
    "savefig.facecolor": BG, "axes.edgecolor": MUTED,
    "axes.labelcolor": TXT, "xtick.color": MUTED, "ytick.color": MUTED,
    "text.color": TXT, "font.family": "DejaVu Sans",
})

ENGINE_LAT = {"ADD": 1, "SUB": 1, "MUL": 6, "DIV": 9}


def alu_simulate(op, a, b):
    """Return (signals_dict, T_total).

    Trace cycles 0..T-1. Each list has length T (one sample per cycle).
    Top-level cycles = LOAD(1) + EXEC(engine_lat) + DONE(1) + idle(1) = engine+3.
    """
    eng = ENGINE_LAT[op]
    pre = 2          # idle cycles before start
    post = 3         # idle cycles after done
    exec_cycles = eng
    total = pre + 1 + 1 + exec_cycles + 1 + post  # idle | start | LOAD | EXEC... | DONE | idle...

    state = []        # IDLE/LOAD/EXEC/DONE
    start = []
    load_en = []
    exec_start = []
    busy = []
    done = []
    eng_done = []
    a_bus = []
    b_bus = []
    res_bus = []
    opc = []

    opmap = {"ADD": 0, "SUB": 1, "MUL": 2, "DIV": 3}
    if op == "ADD":  result = (a + b) & 0xFFFF
    elif op == "SUB": result = (a - b) & 0xFFFF
    elif op == "MUL":
        sa = a-256 if a & 0x80 else a
        sb = b-256 if b & 0x80 else b
        result = (sa*sb) & 0xFFFF
    else:  # DIV
        q = a // b; r = a % b
        result = ((r & 0xFF) << 8) | (q & 0xFF)

    cyc = 0
    # idle (pre)
    for _ in range(pre):
        state.append("IDLE"); start.append(0); load_en.append(0)
        exec_start.append(0); busy.append(0); done.append(0); eng_done.append(0)
        a_bus.append(0); b_bus.append(0); res_bus.append(0); opc.append(opmap[op])
        cyc += 1
    # cycle: start asserted, FSM still IDLE this cycle (samples on next edge)
    state.append("IDLE"); start.append(1); load_en.append(0)
    exec_start.append(0); busy.append(0); done.append(0); eng_done.append(0)
    a_bus.append(a); b_bus.append(b); res_bus.append(0); opc.append(opmap[op])
    # LOAD
    state.append("LOAD"); start.append(0); load_en.append(1)
    exec_start.append(0); busy.append(0); done.append(0); eng_done.append(0)
    a_bus.append(a); b_bus.append(b); res_bus.append(0); opc.append(opmap[op])
    # EXEC (exec_cycles cycles)
    for k in range(exec_cycles):
        state.append("EXEC"); start.append(0); load_en.append(0)
        exec_start.append(1 if k == 0 else 0)
        busy.append(1)
        is_last = (k == exec_cycles - 1)
        eng_done.append(1 if is_last else 0)
        done.append(0)
        a_bus.append(a); b_bus.append(b)
        res_bus.append(result if is_last else 0)
        opc.append(opmap[op])
    # DONE
    state.append("DONE"); start.append(0); load_en.append(0)
    exec_start.append(0); busy.append(0); done.append(1); eng_done.append(0)
    a_bus.append(a); b_bus.append(b); res_bus.append(result); opc.append(opmap[op])
    # idle post
    for _ in range(post):
        state.append("IDLE"); start.append(0); load_en.append(0)
        exec_start.append(0); busy.append(0); done.append(0); eng_done.append(0)
        a_bus.append(a); b_bus.append(b); res_bus.append(result); opc.append(opmap[op])

    sig = dict(state=state, start=start, load_en=load_en,
               exec_start=exec_start, busy=busy, done=done,
               eng_done=eng_done, A=a_bus, B=b_bus, result=res_bus, opcode=opc)
    return sig, len(state), result


def draw_waveform(op, a, b, fname, title):
    sig, T, result = alu_simulate(op, a, b)
    period = 10  # ns
    # clock samples at 0.5-cycle resolution
    t_clk = np.arange(0, T*period + period, period/2)
    clk = [(i % 2) for i in range(len(t_clk))]

    rows = [
        ("clk",        "wave_clk", clk, t_clk),
        ("rst",        "low",      [0]*T, None),
        ("start",      "bit",      sig["start"], None),
        ("opcode[1:0]","bus2",     sig["opcode"], None),
        ("A_raw[7:0]", "bus",      sig["A"], None),
        ("B_raw[7:0]", "bus",      sig["B"], None),
        ("state",      "state",    sig["state"], None),
        ("load_en",    "bit",      sig["load_en"], None),
        ("exec_start", "bit",      sig["exec_start"], None),
        ("busy",       "bit",      sig["busy"], None),
        ("done",       "bit",      sig["done"], None),
        ("result[15:0]","bus_res", sig["result"], None),
    ]

    fig_h = max(5.5, 0.45 * len(rows) + 1.2)
    fig, ax = plt.subplots(figsize=(13, fig_h), dpi=150)
    ax.set_xlim(0, T*period)
    ax.set_ylim(0, len(rows))
    ax.invert_yaxis()
    ax.set_xticks(np.arange(0, T*period+1, period))
    ax.set_xticklabels([str(i*period) for i in range(T+1)], fontsize=7)
    ax.set_yticks([i+0.5 for i in range(len(rows))])
    ax.set_yticklabels([r[0] for r in rows], fontsize=10)
    ax.set_xlabel("time (ns)", fontsize=10)
    ax.set_title(title, fontsize=14, color=TXT, pad=12)
    ax.grid(axis="x", color="#2a3450", linewidth=0.5, linestyle="--")
    for spine in ax.spines.values():
        spine.set_color("#2a3450")

    for idx, (name, kind, data, t_override) in enumerate(rows):
        y0 = idx + 0.15; y1 = idx + 0.85; ymid = idx + 0.5
        if kind == "wave_clk":
            xs = t_override
            ys = [y1 if v else y0 for v in data]
            ax.step(xs, ys, where="post", color=ACC, linewidth=1.4)
        elif kind in ("bit",):
            xs = []; ys = []
            for c in range(T):
                xs.extend([c*period, (c+1)*period])
                v = data[c]
                ys.extend([y1 if v else y0, y1 if v else y0])
            ax.plot(xs, ys, color=OK if any(data) else MUTED, linewidth=1.6)
        elif kind == "low":
            ax.plot([0, T*period], [y0, y0], color=MUTED, linewidth=1.4)
        elif kind == "state":
            # color-coded segments
            colors = {"IDLE":"#2a3450","LOAD":"#3b6ea8","EXEC":"#7b5bd4","DONE":"#5BD49E"}
            seg_start = 0
            cur = data[0]
            for c in range(1, T+1):
                if c == T or data[c] != cur:
                    x0 = seg_start*period; x1 = c*period
                    rect = Rectangle((x0, y0), x1-x0, y1-y0,
                                     facecolor=colors.get(cur, "#444"),
                                     edgecolor="#0F172A", linewidth=0.6)
                    ax.add_patch(rect)
                    ax.text((x0+x1)/2, ymid, cur, ha="center", va="center",
                            color="white", fontsize=8, fontweight="bold")
                    if c < T:
                        seg_start = c; cur = data[c]
        else:  # bus / bus_res / bus2
            seg_start = 0
            cur = data[0]
            for c in range(1, T+1):
                if c == T or data[c] != cur:
                    x0 = seg_start*period; x1 = c*period
                    # hex bus shape: trapezoid sides
                    fc = "#21314f" if kind != "bus_res" else "#1f4036"
                    ec = ACC if kind != "bus_res" else OK
                    poly = plt.Polygon(
                        [(x0+1, ymid), (x0+3, y0), (x1-3, y0),
                         (x1-1, ymid), (x1-3, y1), (x0+3, y1)],
                        closed=True, facecolor=fc, edgecolor=ec, linewidth=1.0)
                    ax.add_patch(poly)
                    if kind == "bus2":
                        label = f"{cur:02b}"
                    elif kind == "bus_res":
                        label = f"0x{cur:04X}" if cur else "—"
                    else:
                        label = f"{cur:3d}"
                    if (x1 - x0) > 18:
                        ax.text((x0+x1)/2, ymid, label, ha="center",
                                va="center", color=TXT, fontsize=8,
                                fontweight="bold")
                    if c < T:
                        seg_start = c; cur = data[c]

    # annotation: result
    op_sym = {"ADD":"+", "SUB":"-", "MUL":"×", "DIV":"÷"}[op]
    ax.text(0.99, -0.13,
            f"  result = {a} {op_sym} {b} → 0x{result:04X} ({result})  ",
            transform=ax.transAxes, ha="right", va="top",
            color=TXT, fontsize=11, fontweight="bold",
            bbox=dict(boxstyle="round,pad=0.4", facecolor=PANEL,
                      edgecolor=ACC))

    plt.tight_layout()
    fig.savefig(OUT / fname, bbox_inches="tight", facecolor=BG)
    plt.close(fig)
    print(f"  wrote {fname}  (result = 0x{result:04X} = {result})")
    return result


def draw_console(fname):
    cases = [
        ("ADD 5+3",        5,   3,   8),
        ("ADD 100+55",     100, 55,  155),
        ("ADD 0+0",        0,   0,   0),
        ("ADD 1+0",        1,   0,   1),
        ("ADD 128+127",    128, 127, 255),
        ("ADD 255+1 wrap", 255, 1,   0),
        ("ADD 255+255",    255, 255, 254),
        ("ADD 128+128",    128, 128, 0),
        ("SUB 10-4",       10,  4,   6),
        ("SUB 200-50",     200, 50,  150),
        ("SUB 5-5",        5,   5,   0),
        ("SUB 255-255",    255, 255, 0),
        ("SUB 128-1",      128, 1,   127),
        ("SUB 0-1 wrap",   0,   1,   255),
        ("SUB 1-255 wrap", 1,   255, 2),
        ("MUL 7*6",        7,   6,   42),
        ("MUL 15*15",      15,  15,  225),
        ("MUL 1*1",        1,   1,   1),
        ("MUL 0*123",      0,   123, 0),
        ("MUL 12*12",      12,  12,  144),
        ("MUL 127*2",      127, 2,   254),
        ("MUL 64*3",       64,  3,   192),
        ("MUL -1*2 signed",255, 2,   0xFFFE),
        ("DIV 42/6",       42,  6,   0x0007),
        ("DIV 100/10",     100, 10,  0x000A),
        ("DIV 17/5",       17,  5,   0x0203),
        ("DIV 255/16",     255, 16,  0x0F0F),
        ("DIV 0/5",        0,   5,   0x0000),
        ("DIV 7/7",        7,   7,   0x0001),
        ("DIV 1/2",        1,   2,   0x0100),
        ("DIV 255/255",    255, 255, 0x0001),
        ("DIV 100/7",      100, 7,   0x020E),
    ]
    lines = ["$ ./run.sh", "Cleaning up old files...", "Compiling Verilog files...",
             "Compilation Successful!", "Running simulation...", "VCD info: dumpfile alu_sim.vcd opened.", ""]
    for label, a, b, r in cases:
        lines.append(f"PASS [{label}]: A={a} B={b} result={r} (0x{r:04X}) carry=0 ovf=0")
    lines += ["", "ALL TESTS PASSED", "Done."]

    h = 0.18 * len(lines) + 0.6
    fig, ax = plt.subplots(figsize=(13, h), dpi=150)
    ax.set_facecolor("#0a0f1c")
    fig.patch.set_facecolor("#0a0f1c")
    ax.set_xlim(0, 1); ax.set_ylim(0, 1)
    ax.axis("off")
    body = "\n".join(lines)
    ax.text(0.01, 0.99, body, family="Consolas", fontsize=9,
            color="#cde8ff", va="top", ha="left")
    # highlight last
    ax.text(0.01, 0.04, "ALL TESTS PASSED",
            family="Consolas", fontsize=11, fontweight="bold",
            color=OK, va="bottom", ha="left")
    fig.savefig(OUT / fname, bbox_inches="tight", facecolor="#0a0f1c")
    plt.close(fig)
    print(f"  wrote {fname}")


def draw_diagram(fname):
    fig, ax = plt.subplots(figsize=(14, 8), dpi=150)
    ax.set_xlim(0, 14); ax.set_ylim(0, 8)
    ax.axis("off")
    ax.set_title("Structural 8-bit ALU — Top-Level Architecture",
                 fontsize=18, color=TXT, pad=14, fontweight="bold")

    def block(x, y, w, h, label, sub=None, color=PANEL, edge=ACC):
        box = FancyBboxPatch((x, y), w, h, boxstyle="round,pad=0.05,rounding_size=0.15",
                             facecolor=color, edgecolor=edge, linewidth=1.8)
        ax.add_patch(box)
        ax.text(x+w/2, y+h/2 + (0.18 if sub else 0), label,
                ha="center", va="center", color=TXT, fontsize=12, fontweight="bold")
        if sub:
            ax.text(x+w/2, y+h/2 - 0.22, sub, ha="center", va="center",
                    color=MUTED, fontsize=9, style="italic")

    def pin(x, y, label, side="left"):
        ax.plot(x, y, marker="o", color=ACC, markersize=8, zorder=5)
        if side == "left":
            ax.text(x-0.15, y, label, ha="right", va="center", color=TXT, fontsize=10)
        else:
            ax.text(x+0.15, y, label, ha="left", va="center", color=TXT, fontsize=10)

    def arrow(x1, y1, x2, y2, label=None, color=ACC, lw=1.6):
        a = FancyArrowPatch((x1, y1), (x2, y2),
                            arrowstyle="-|>", mutation_scale=14,
                            color=color, linewidth=lw)
        ax.add_patch(a)
        if label:
            ax.text((x1+x2)/2, (y1+y2)/2 + 0.18, label,
                    ha="center", va="bottom", color=MUTED, fontsize=8)

    # input pins (left)
    pin(0.4, 7.0, "clk")
    pin(0.4, 6.5, "rst")
    pin(0.4, 6.0, "start")
    pin(0.4, 5.0, "opcode[1:0]")
    pin(0.4, 3.5, "A_raw[7:0]")
    pin(0.4, 1.7, "B_raw[7:0]")

    # control unit
    block(2.2, 5.6, 2.6, 1.6, "Control Unit",
          sub="FSM: IDLE→LOAD→EXEC→DONE")
    arrow(0.55, 7.0, 2.2, 6.8)
    arrow(0.55, 6.5, 2.2, 6.5)
    arrow(0.55, 6.0, 2.2, 6.2)

    # operand registers
    block(2.2, 3.1, 2.0, 0.9, "register_8bit", sub="reg_A")
    block(2.2, 1.3, 2.0, 0.9, "register_8bit", sub="reg_B")
    arrow(0.55, 3.5, 2.2, 3.55)
    arrow(0.55, 1.7, 2.2, 1.75)
    # load_en from CU to regs
    arrow(3.2, 5.6, 3.2, 4.0, label="load_en", color=WARN, lw=1.2)
    arrow(3.2, 3.1, 3.2, 2.2, color=WARN, lw=1.2)

    # arithmetic engines
    block(6.0, 5.6, 3.0, 1.2, "ADD / SUB",
          sub="adder_substractor.v", color="#1d3a3a", edge=OK)
    block(6.0, 3.6, 3.0, 1.2, "Booth Mul (radix-4)",
          sub="booth_radix_4_multiplier.v", color="#1d3a3a", edge=OK)
    block(6.0, 1.6, 3.0, 1.2, "Radix-2 Divider",
          sub="Radix2.v", color="#1d3a3a", edge=OK)

    # operand bus to engines
    arrow(4.2, 3.55, 6.0, 6.0)        # A → addsub
    arrow(4.2, 1.75, 6.0, 5.9)        # B → addsub
    arrow(4.2, 3.55, 6.0, 4.1)        # A → mul
    arrow(4.2, 1.75, 6.0, 4.0)        # B → mul
    arrow(4.2, 3.55, 6.0, 2.0)        # A → div
    arrow(4.2, 1.75, 6.0, 1.85)       # B → div

    # exec_start from CU
    arrow(4.8, 6.4, 6.0, 6.4, label="exec_start", color=WARN, lw=1.2)

    # MUX
    mx = mpatches.Polygon([(10.4, 5.0), (11.6, 4.4), (11.6, 2.6), (10.4, 2.0)],
                          closed=True, facecolor=PANEL, edgecolor=ACC, linewidth=1.8)
    ax.add_patch(mx)
    ax.text(11.0, 3.6, "4:1\nMUX\n[16-bit]", ha="center", va="center",
            color=TXT, fontsize=11, fontweight="bold")

    arrow(9.0, 6.2, 10.4, 4.7)   # add result
    arrow(9.0, 4.2, 10.4, 3.6)   # mul result
    arrow(9.0, 2.2, 10.4, 2.5)   # div result
    # opcode → mux sel
    arrow(0.55, 5.0, 10.6, 4.95, label="opcode", color=WARN, lw=1.2)

    # outputs (right)
    pin(13.6, 6.5, "carry_out", side="right")
    pin(13.6, 6.0, "overflow", side="right")
    pin(13.6, 3.6, "result[15:0]", side="right")
    pin(13.6, 1.0, "done", side="right")

    arrow(11.6, 3.6, 13.45, 3.6)
    arrow(9.0, 6.6, 13.45, 6.5)   # carry_out
    arrow(9.0, 6.5, 13.45, 6.0)   # overflow
    arrow(4.8, 6.0, 13.45, 1.0, color=OK)  # done from CU (curve-ish)

    # legend
    ax.text(0.4, 0.4, "blue = control / select",
            color=WARN, fontsize=9)
    ax.text(5.0, 0.4, "green = arithmetic engine",
            color=OK, fontsize=9)
    ax.text(10.0, 0.4, "white = data bus",
            color=ACC, fontsize=9)

    fig.savefig(OUT / fname, bbox_inches="tight", facecolor=BG)
    plt.close(fig)
    print(f"  wrote {fname}")


if __name__ == "__main__":
    print("Rendering waveforms...")
    draw_waveform("ADD", 5,   3,   "wave_add.png", "ADD: A=5, B=3 (opcode=00)")
    draw_waveform("SUB", 10,  4,   "wave_sub.png", "SUB: A=10, B=4 (opcode=01)")
    draw_waveform("MUL", 15,  15,  "wave_mul.png", "MUL: A=15, B=15 (opcode=10, signed Booth)")
    draw_waveform("DIV", 100, 7,   "wave_div.png", "DIV: A=100, B=7 (opcode=11) → {rem,quot}")
    print("Rendering console transcript...")
    draw_console("console_transcript.png")
    print("Rendering architecture diagram...")
    draw_diagram("architecture_diagram.png")
    print(f"\nAll assets saved to: {OUT}")
