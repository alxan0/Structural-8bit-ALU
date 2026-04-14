# Structural-8bit-ALU

Structural 8-bit ALU with operation select through `opcode`:
- `00`: add
- `01`: subtract
- `10`: multiply
- `11`: divide

## Architecture

Top module: `src/alu_top.v`

Core flow:
1. `control_unit` sequences IDLE -> LOAD -> EXEC -> DONE.
2. Inputs are latched in `register_8bit` during LOAD.
3. EXEC starts the selected arithmetic unit.
4. `done` is asserted by control when the selected unit finishes.

Arithmetic units:
- Add/Sub: `src/arithmetic/adder/adder_substractor.v`
- Multiply: `src/arithmetic/multiplier/booth_radix_4_multiplier.v`
- Divide: `src/arithmetic/division/Radix2.v`

## Multiplication Algorithm (current)

Multiplier module: `booth_radix_4_multiplier`

Implemented algorithm: signed (two's complement) Booth Radix-4, sequential (4 iterations for 8-bit operands).

Internal idea:
1. `acc` holds the running 16-bit accumulated result.
2. `x_shift` starts from sign-extended multiplicand `{{8{multiplicand[7]}}, multiplicand}` and shifts left by 2 every cycle.
3. `y_ext` starts from `{multiplier, 1'b0}` and shifts right arithmetically by 2 every cycle.
4. At each iteration, `y_ext[2:0]` is decoded into one of: `0`, `+X`, `+2X`, `-X`, `-2X`.
5. Accumulation uses existing structural adder blocks (`carry_select_adder`) as a 16-bit chained adder.
6. Subtraction (`-X` / `-2X`) is implemented with two's complement using existing `xor_wordgate` plus carry-in `1`.

Why Radix-4:
- Processes 2 multiplier bits per cycle.
- Reduces cycles vs. basic shift-add (4 vs. 8 iterations for 8-bit multiply).

## Run ALU testbench

Use `run.sh` to compile and run the integrated ALU testbench.

## Run Booth multiplier testbench only

Compile and run:

```bash
iverilog -o booth_mul_sim \
	src/arithmetic/adder/full_adder_cell.v \
	src/arithmetic/adder/mux2to1.v \
	src/arithmetic/adder/adder_level.v \
	src/arithmetic/adder/ripple_carry_adder.v \
	src/arithmetic/adder/xor_wordgate.v \
	src/arithmetic/adder/carry_select_adder.v \
	src/arithmetic/multiplier/booth_radix_4_multiplier.v \
	src/arithmetic/multiplier/booth_radix_4_multiplier_tb.v

vvp booth_mul_sim
```