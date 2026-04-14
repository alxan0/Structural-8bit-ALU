#!/bin/bash

OUT_FILE="alu_sim_bin"
VCD_FILE="alu_sim.vcd"

echo "Cleaning up old files..."
rm -f $OUT_FILE $VCD_FILE

echo "Compiling Verilog files..."
iverilog -o $OUT_FILE \
    src/alu_top.v \
    src/control/control_unit.v \
    src/common/register_8bit.v \
    src/arithmetic/adder/full_adder_cell.v \
    src/arithmetic/adder/mux2to1.v \
    src/arithmetic/adder/adder_level.v \
    src/arithmetic/adder/ripple_carry_adder.v \
    src/arithmetic/adder/xor_wordgate.v \
    src/arithmetic/adder/carry_select_adder.v \
    src/arithmetic/adder/adder_substractor.v \
    src/arithmetic/multiplier/booth_radix_4_multiplier.v \
    src/arithmetic/division/Radix2.v \
    sim/alu_tb.v

if [ $? -eq 0 ]; then
    echo "Compilation Successful!"
else
    echo "Compilation FAILED. Check your syntax."
    exit 1
fi

echo "Running simulation..."
vvp $OUT_FILE

if [ "$1" == "--view" ]; then
    echo "Opening GTKWave..."
    gtkwave $VCD_FILE &
fi

echo "Done."