#!/bin/bash

OUT_FILE="alu_sim_bin"
VCD_FILE="alu_sim.vcd"

# Step 1: Cleanup
echo "Cleaning up old files..."
rm -f $OUT_FILE $VCD_FILE

# Step 2: Compile
echo "Compiling Verilog files..."
iverilog -o $OUT_FILE \
    src/alu_top.v \
    src/control/control_unit.v \
    src/common/register_8bit.v \
    sim/alu_tb.v

if [ $? -eq 0 ]; then
    echo "Compilation Successful!"
else
    echo "Compilation FAILED. Check your syntax."
    exit 1
fi

# Step 3: Run Simulation
echo "Running simulation..."
vvp $OUT_FILE

# Step 4: Open Waveform
if [ "$1" == "--view" ]; then
    echo "Opening GTKWave..."
    gtkwave $VCD_FILE &
fi

echo "Done."