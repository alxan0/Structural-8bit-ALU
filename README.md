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

## Run ALU testbench

Use `run.sh` to compile and run the integrated ALU testbench.