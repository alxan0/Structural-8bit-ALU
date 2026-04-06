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

    task run_op_and_check;
        input [7:0] in_a;
        input [7:0] in_b;
        input [1:0] in_opcode;
        input [7:0] expected_low;
        begin
            @(negedge clk);
            A_raw = in_a;
            B_raw = in_b;
            opcode = in_opcode;
            start = 1'b1;

            @(negedge clk);
            start = 1'b0;

            wait(done == 1'b1);
            #1;

            if (result[7:0] !== expected_low) begin
                $display("FAIL: opcode=%b A=%0d B=%0d expected=%0d got=%0d", in_opcode, in_a, in_b, expected_low, result[7:0]);
                $fatal(1);
            end else begin
                $display("PASS: opcode=%b A=%0d B=%0d result=%0d", in_opcode, in_a, in_b, result[7:0]);
            end

            wait(done == 1'b0);
        end
    endtask

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
        run_op_and_check(8'd5, 8'd3, 2'b00, 8'd8);

        // TEST 2: Subtraction (10 - 4)
        run_op_and_check(8'd10, 8'd4, 2'b01, 8'd6);

        // TEST 3: Unsupported opcode should output 0 in low byte
        run_op_and_check(8'd12, 8'd7, 2'b10, 8'd0);

        #20;
        $finish;
    end

    initial begin
        $dumpfile("alu_sim.vcd");
        $dumpvars(0, alu_tb);
    end

endmodule