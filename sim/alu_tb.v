`timescale 1ns / 1ps

module alu_tb;
    reg clk;
    reg rst;
    reg start;
    reg [1:0] opcode;
    reg [7:0] A_raw;
    reg [7:0] B_raw;

    wire [15:0] result;
    wire carry_out;
    wire overflow;
    wire done;

    alu_top uut (
        .clk(clk), .rst(rst), .start(start),
        .opcode(opcode), .A_raw(A_raw), .B_raw(B_raw),
        .result(result), .carry_out(carry_out), .overflow(overflow),
        .done(done)
    );

    always #5 clk = ~clk;

    task run_op;
        input [7:0] in_a;
        input [7:0] in_b;
        input [1:0] in_op;
        input [15:0] expected;
        input [8*20-1:0] label;
        begin
            @(negedge clk);
            A_raw  = in_a;
            B_raw  = in_b;
            opcode = in_op;
            start  = 1'b1;

            @(negedge clk);
            start = 1'b0;

            wait (done == 1'b1);
            #1;

            if (result !== expected) begin
                $display("FAIL [%0s]: A=%0d B=%0d expected=%0d got=%0d (hex: exp=0x%04h got=0x%04h)",
                         label, in_a, in_b, expected, result, expected, result);
                $fatal(1);
            end else begin
                $display("PASS [%0s]: A=%0d B=%0d result=%0d (0x%04h) carry=%b ovf=%b",
                         label, in_a, in_b, result, result, carry_out, overflow);
            end

            wait (done == 1'b0);
        end
    endtask

    initial begin
        clk = 0; rst = 1; start = 0;
        opcode = 2'b00; A_raw = 0; B_raw = 0;

        #20 rst = 0;

        // --- Addition (opcode 00) ---
        run_op(8'd5,   8'd3,   2'b00, 16'd8,   "ADD 5+3");
        run_op(8'd100, 8'd55,  2'b00, 16'd155, "ADD 100+55");
        run_op(8'd0,   8'd0,   2'b00, 16'd0,   "ADD 0+0");
        run_op(8'd1,   8'd0,   2'b00, 16'd1,   "ADD 1+0");
        run_op(8'd128, 8'd127, 2'b00, 16'd255, "ADD 128+127");
        run_op(8'd255, 8'd1,   2'b00, 16'd0,   "ADD 255+1 wrap");
        run_op(8'd255, 8'd255, 2'b00, 16'd254, "ADD 255+255 wrap");
        run_op(8'd128, 8'd128, 2'b00, 16'd0,   "ADD 128+128 wrap");

        // --- Subtraction (opcode 01) ---
        run_op(8'd10,  8'd4,   2'b01, 16'd6,   "SUB 10-4");
        run_op(8'd200, 8'd50,  2'b01, 16'd150, "SUB 200-50");
        run_op(8'd5,   8'd5,   2'b01, 16'd0,   "SUB 5-5");
        run_op(8'd255, 8'd255, 2'b01, 16'd0,   "SUB 255-255");
        run_op(8'd128, 8'd1,   2'b01, 16'd127, "SUB 128-1");
        run_op(8'd0,   8'd1,   2'b01, 16'd255, "SUB 0-1 wrap");
        run_op(8'd1,   8'd255, 2'b01, 16'd2,   "SUB 1-255 wrap");

        // --- Multiplication (opcode 10, signed Booth) ---
        run_op(8'd7,   8'd6,   2'b10, 16'd42,   "MUL 7*6");
        run_op(8'd15,  8'd15,  2'b10, 16'd225,  "MUL 15*15");
        run_op(8'd1,   8'd1,   2'b10, 16'd1,    "MUL 1*1");
        run_op(8'd0,   8'd123, 2'b10, 16'd0,    "MUL 0*123");
        run_op(8'd12,  8'd12,  2'b10, 16'd144,  "MUL 12*12");
        run_op(8'd127, 8'd2,   2'b10, 16'd254,  "MUL 127*2");
        run_op(8'd64,  8'd3,   2'b10, 16'd192,  "MUL 64*3");
        run_op(8'd255, 8'd2,   2'b10, 16'hFFFE, "MUL -1*2 signed");

        // --- Division (opcode 11), result = {remainder, quotient} ---
        run_op(8'd42,  8'd6,   2'b11, {8'd0,  8'd7},  "DIV 42/6");
        run_op(8'd100, 8'd10,  2'b11, {8'd0,  8'd10}, "DIV 100/10");
        run_op(8'd17,  8'd5,   2'b11, {8'd2,  8'd3},  "DIV 17/5");
        run_op(8'd255, 8'd16,  2'b11, {8'd15, 8'd15}, "DIV 255/16");
        run_op(8'd0,   8'd5,   2'b11, {8'd0,  8'd0},  "DIV 0/5");
        run_op(8'd7,   8'd7,   2'b11, {8'd0,  8'd1},  "DIV 7/7");
        run_op(8'd1,   8'd2,   2'b11, {8'd1,  8'd0},  "DIV 1/2");
        run_op(8'd255, 8'd255, 2'b11, {8'd0,  8'd1},  "DIV 255/255");
        run_op(8'd100, 8'd7,   2'b11, {8'd2,  8'd14}, "DIV 100/7");

        #50;
        $display("ALL TESTS PASSED");
        $finish;
    end

    initial begin
        $dumpfile("alu_sim.vcd");
        $dumpvars(0, alu_tb);
    end

endmodule
