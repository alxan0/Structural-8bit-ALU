# Structural 8-bit ALU

## 1. Scope and Functional Definition

This document defines the architecture, interfaces, and behavior of the Structural 8-bit ALU implementation in this repository.

The ALU accepts two 8-bit operands (`A_raw`, `B_raw`) and a 2-bit opcode, then executes one of four operations:
- addition
- subtraction
- multiplication
- division

The design provides a unified 16-bit result bus, operation-completion handshake (`start`/`done`), and operation-status outputs (`carry_out`, `overflow`) for add/sub cases.

## 2. System Overview

The design is composed of:
- one top-level integration module: `alu_top`
- one control FSM: `control_unit`
- three arithmetic engines:
  - add/subtract engine (`adder_substractor`)
  - multiplier engine (`booth_radix_4_multiplier`)
  - divider engine (`radix2_div`)
- shared structural primitives under `src/common`

Top-level operation sequence:
1. external operands are captured into internal operand registers
2. control FSM enters execute phase
3. selected arithmetic engine runs
4. done is unified and exposed at top-level output

## 3. External Interface Specification

Top-level module: `src/alu_top.v`

| Signal | Dir | Width | Description | Notes |
|---|---|---:|---|---|
| `clk` | in | 1 | system clock | sampled on rising edge |
| `rst` | in | 1 | asynchronous reset (active high) | clears control and state registers |
| `start` | in | 1 | operation request/handshake | assert for at least one cycle in `IDLE` (pulse is valid); may also be held high until `done` |
| `opcode` | in | 2 | operation selector | `00:add`, `01:sub`, `10:mul`, `11:div` |
| `A_raw` | in | 8 | operand A | latched during `LOAD` |
| `B_raw` | in | 8 | operand B | latched during `LOAD` |
| `result` | out | 16 | operation result bus | encoding depends on opcode |
| `carry_out` | out | 1 | add/sub carry-out | meaningful for add/sub path |
| `overflow` | out | 1 | add/sub signed overflow | meaningful for add/sub path |
| `done` | out | 1 | top-level completion signal | asserted in controller `DONE` state |

### 3.1 Opcode map

| opcode | operation | selected engine | `result` format |
|---|---|---|---|
| `2'b00` | add | `adder_substractor` (`sub_mode=0`) | `{8'b0, sum[7:0]}` |
| `2'b01` | subtract | `adder_substractor` (`sub_mode=1`) | `{8'b0, diff[7:0]}` |
| `2'b10` | multiply | `booth_radix_4_multiplier` | `product[15:0]` |
| `2'b11` | divide | `radix2_div` | `{remainder[7:0], quotient[7:0]}` |

## 4. Top-Level Architecture (`alu_top`)

File: `src/alu_top.v`

`alu_top` is responsible for:
- opcode decode and operation select
- operand capture through `register_8bit`
- dispatch of execution start
- merge of engine busy/done status
- merge of engine results into one output bus

### 4.1 Key integration behavior

Control unit interface:

```verilog
control_unit brain (
    .clk(clk), .rst(rst), .start(start),
    .exec_done(effective_done),
    .exec_busy(effective_busy),
    .load_en(load_en),
    .exec_start(exec_start),
    .done(done)
);
```

Operand registers:

```verilog
register_8bit reg_A (... .load_en(load_en), .data_in(A_raw), .data_out(A_internal));
register_8bit reg_B (... .load_en(load_en), .data_in(B_raw), .data_out(B_internal));
```

Arithmetic dispatch:

```verilog
adder_substractor add_sub_unit (
    .start(exec_start), .enable(sel_addsub), .sub_mode(sel_sub),
    .busy(addsub_busy), .done(addsub_done), .result(addsub_result)
);

booth_radix_4_multiplier mul_unit (
    .start(exec_start), .enable(sel_mul),
    .busy(mul_busy), .done(mul_done), .product(mul_result)
);

radix2_div div_unit (
    .start(exec_start & sel_div),
    .ready(div_ready), .done(div_done),
    .quotient(div_quotient), .remainder(div_remainder)
);
```

### 4.2 Unified control handshake

`effective_busy` and `effective_done` are selected using opcode-driven muxes:
- add/sub path: `addsub_busy`, `addsub_done`
- mul path: `mul_busy`, `mul_done`
- div path: `~div_ready`, `div_done`

This allows a single control FSM implementation to supervise all operations.

## 5. Control Unit Specification (`control_unit`)

File: `src/control/control_unit.v`

### 5.1 State encoding

| State | Encoding |
|---|---|
| `IDLE` | `2'b00` |
| `LOAD` | `2'b01` |
| `EXEC` | `2'b10` |
| `DONE` | `2'b11` |

### 5.2 Transition logic

```verilog
case (state)
    IDLE:    next_state = start     ? LOAD : IDLE;
    LOAD:    next_state = EXEC;
    EXEC:    next_state = exec_done ? DONE : EXEC;
    DONE:    next_state = start     ? DONE : IDLE;
    default: next_state = IDLE;
endcase
```

### 5.3 Transition table

| Current | Condition | Next | Intent |
|---|---|---|---|
| `IDLE` | `start=0` | `IDLE` | wait for request |
| `IDLE` | `start=1` | `LOAD` | capture operands |
| `LOAD` | always | `EXEC` | single-cycle load stage |
| `EXEC` | `exec_done=0` | `EXEC` | continue execution |
| `EXEC` | `exec_done=1` | `DONE` | operation complete |
| `DONE` | `start=1` | `DONE` | hold completion |
| `DONE` | `start=0` | `IDLE` | handshake release |

### 5.4 Output table

| State | `load_en` | `exec_start` | `done` |
|---|---:|---:|---:|
| `IDLE` | 0 | 0 | 0 |
| `LOAD` | 1 | 0 | 0 |
| `EXEC` | 0 | `!exec_busy && !exec_done` | 0 |
| `DONE` | 0 | 0 | 1 |

### 5.5 Handshake requirement

`start` only needs to be asserted long enough for the controller to observe it in `IDLE` (a one-cycle pulse is sufficient).

If `start` remains high after completion, `done` remains high in `DONE` and the controller stays there. Deassert `start` to return to `IDLE`.

## 6. Arithmetic Component Specifications

### 6.1 Add/Sub (`adder_substractor`)

File: `src/arithmetic/adder/adder_substractor.v`

Functional behavior:
- if `sub_mode=0`: compute `op1 + op2`
- if `sub_mode=1`: compute `op1 + (~op2) + 1`

Datapath implementation:

```verilog
xor_wordgate #(.w(8)) gate (.in(op2), .bit_in(sub_mode), .out(op2_xor));
carry_select_adder add (.op1(op1), .op2(op2_xor), .c_in(sub_mode), ...);
```

Status outputs:
- `c_out`: carry-out of the 8-bit adder
- `overflow`: signed overflow, computed by

```verilog
assign overflow_raw = (op1[7]==op2_xor[7]) && (adder_result[7] != op1[7]);
```

Control behavior:
- requires `enable=1`
- consumes `start`
- exposes `busy` and one-cycle `done` pulse

### 6.2 Multiply (`booth_radix_4_multiplier`)

File: `src/arithmetic/multiplier/booth_radix_4_multiplier.v`

Algorithm:
- signed radix-4 Booth multiplication
- 8-bit by 8-bit input, 16-bit output
- 4 recoding iterations (`count = 4`)

Internal state:
- `acc[15:0]`
- `x_shift[15:0]`
- `y_ext[8:0]`
- `count`

Booth decode over `y_ext[2:0]`:
- `001`, `010` => `+X`
- `011` => `+2X`
- `100` => `-2X`
- `101`, `110` => `-X`
- default => `0`

Module FSM:
- `IDLE` -> wait for start
- `CALC` -> iterate Booth updates
- `FINISH` -> publish product, pulse done

### 6.3 Divide (`radix2_div`)

File: `src/arithmetic/division/Radix2.v`

Algorithm:
- unsigned radix-2 restoring division
- default `WIDTH=8`

Registers:
- `A` (partial remainder)
- `M` (divisor)
- `Q` (quotient register)
- `count` (iteration count)

Per-cycle operation:
1. shift boundary between `A` and `Q`
2. subtract divisor
3. keep subtraction result and insert 1 in Q if non-negative
4. otherwise restore and insert 0 in Q

Completion behavior:
- `quotient <= Q`
- `remainder <= A`
- `done <= 1`
- `ready <= 1`

Module states:

| Current | Condition | Next |
|---|---|---|
| `IDLE` | `start=0` | `IDLE` |
| `IDLE` | `start=1` | `CALC` |
| `CALC` | `count>0` | `CALC` |
| `CALC` | `count==0` | `IDLE` |

Constraint:
- no dedicated divide-by-zero error signaling is implemented.

## 7. Common Structural Blocks

Directory: `src/common`

| Module | Role |
|---|---|
| `full_adder_cell` | 1-bit full adder primitive |
| `ripple_carry_adder` | parameterized ripple adder chain |
| `adder_level` | dual-carry precompute/select stage |
| `carry_select_adder` | 8-bit adder using ripple + carry-select |
| `xor_wordgate` | word-wise XOR with replicated control bit |
| `mux2to1` | generic 2:1 mux |
| `register_8bit` | operand storage register |

The ALU architecture is intentionally structural: higher-level arithmetic units are composed from these reusable blocks.

## 8. End-to-End Functional Timing

For any valid opcode, the top-level behavior shall be:
1. `start` asserted with stable `A_raw`, `B_raw`, `opcode`
2. control enters `LOAD` and latches operands
3. control enters `EXEC` and drives `exec_start` for selected engine
4. selected engine asserts local done condition
5. control enters `DONE` and asserts top-level `done`
6. caller deasserts `start`, allowing return to `IDLE`

## 9. Performance and Latency

Latency is reported in clock cycles. To provide concrete time values, the current integrated testbench clock is also shown:
- `sim/alu_tb.v` uses `always #5 clk = ~clk;`
- clock period = 10 ns

Two latency viewpoints are useful:
- engine latency: from `exec_start` sampled by the arithmetic engine to that engine's local `done`
- top-level latency: from `start` sampled in `IDLE` by `control_unit` to top-level `done`

| Operation | Engine latency (cycles) | Top-level latency (cycles) | Top-level latency at 10 ns clk |
|---|---:|---:|---:|
| Add (`opcode=00`) | 1 | 4 | 40 ns |
| Sub (`opcode=01`) | 1 | 4 | 40 ns |
| Mul (`opcode=10`) | 6 | 9 | 90 ns |
| Div (`opcode=11`) | 9 | 12 | 120 ns |

Top-level latency includes fixed control overhead (`LOAD`, dispatch in `EXEC`, and transition to `DONE`).

### 9.1 Efficiency interpretation

- Add/Sub is the fastest path in this architecture because its datapath is combinational and only uses a short handshake.
- Multiply is medium latency because Booth radix-4 reduces the number of partial-product iterations to 4 (for 8-bit inputs), but remains sequential.
- Divide is the slowest path because radix-2 restoring division performs one quotient-bit update per cycle and requires restore logic.

## 10. Algorithm Selection Rationale and Trade-offs

### 10.1 Add/Sub algorithm choice

Chosen approach:
- two's-complement add/sub reuse (`A + B` or `A + (~B) + 1`)
- `carry_select_adder` for the arithmetic core

Why this was chosen:
- one shared datapath supports both add and subtract with minimal control complexity
- keeps the design structural and reusable with existing common blocks

Advantages:
- compact control model (single `sub_mode` bit)
- faster than pure ripple at 8-bit width due to carry-select upper stage
- straightforward carry and overflow flag generation

Disadvantages:
- carry-select duplicates some logic, increasing area versus pure ripple
- fixed 8-bit composition is less flexible than a fully parameterized arithmetic core

### 10.2 Multiplier algorithm choice

Chosen approach:
- signed Booth radix-4 iterative multiplier

Why this was chosen:
- naturally supports signed operands
- reduces iteration count compared with radix-2 Booth and shift-add baseline
- aligns with structural, clocked datapath style of the project

Advantages:
- fewer arithmetic iterations (4 for 8-bit inputs)
- signed arithmetic handling is integrated in the recoding process
- moderate hardware footprint compared with fully parallel multipliers

Disadvantages:
- multi-cycle latency (not single-cycle throughput)
- control and datapath are more complex than simple shift-add multipliers
- additional state/register movement per cycle increases control overhead

### 10.3 Divider algorithm choice

Chosen approach:
- radix-2 restoring division

Why this was chosen:
- deterministic, easy-to-follow algorithm suitable for structural implementation
- clear mapping to quotient/remainder registers and per-cycle control

Advantages:
- simple and robust control behavior
- predictable cycle count at fixed width
- straightforward functional verification against `a / b` and `a % b`

Disadvantages:
- highest latency among implemented operations
- restoring step adds extra work in unsuccessful subtraction cases
- current implementation has no explicit divide-by-zero exception signaling

### 10.4 Overall architectural trade-off

The selected arithmetic algorithms prioritize:
- structural clarity
- modular reuse of shared building blocks
- deterministic multi-cycle control

over:
- minimum possible latency
- maximum throughput of deeply parallel arithmetic units

## 11. Verification References

| Artifact | File |
|---|---|
| Integrated ALU testbench | `sim/alu_tb.v` |
| Multiplier testbench | `src/arithmetic/multiplier/booth_radix_4_multiplier_tb.v` |
| Divider testbench | `src/arithmetic/division/Radix2_tb.v` |
| Run script | `run.sh` |
