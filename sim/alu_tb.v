`timescale 1ns / 1ps

module alu_tb;
    reg clk;
    reg rst;
    reg start;
    reg [1:0] opcode;
    reg [7:0] A_raw;
    reg [7:0] B_raw;
    
    wire [15:0] result;
    wire done;

    alu_top uut (
        .clk(clk), .rst(rst), .start(start),
        .opcode(opcode), .A_raw(A_raw), .B_raw(B_raw),
        .result(result), .done(done)
    );

    always #5 clk = ~clk;

    initial begin
        // Initialize everything
        clk = 0; rst = 1; start = 0; 
        opcode = 2'b00; A_raw = 8'h00; B_raw = 8'h00;

        #20 rst = 0;
        
        // TEST 1: Addition (5 + 3)
        #10;
        A_raw = 8'd5; B_raw = 8'd3; opcode = 2'b00;
        start = 1;
        
        #10 start = 0;
        
        // Wait for 'done' signal
        wait(done == 1);
        $display("Time: %t | Op: Add | Result: %d", $time, result);

        // TEST 2: Subtraction (10 - 4)
        #50;
        A_raw = 8'd10; B_raw = 8'd4; opcode = 2'b01; // Sub
        start = 1;
        #10 start = 0;
        
        wait(done == 1);
        $display("Time: %t | Op: Sub | Result: %d", $time, result);

        #100;
        $finish;
    end

    initial begin
        $dumpfile("alu_sim.vcd");
        $dumpvars(0, alu_tb);
    end

endmodule