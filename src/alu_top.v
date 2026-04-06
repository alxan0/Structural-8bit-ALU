module alu_top (
    input clk,
    input rst,
    input start,
    input [1:0] opcode,
    input [7:0] A_raw,
    input [7:0] B_raw,
    output [15:0] result,
    output done
);
    wire load_en;
    wire exec_start;
    wire [7:0] A_internal, B_internal;
    wire op_valid;
    wire sub_mode;
    wire exec_busy;
    wire exec_done;
    wire c_out;
    wire overflow;
    wire [7:0] arithmetic_out;
    wire [7:0] selected_result;
    wire effective_exec_busy;
    wire effective_exec_done;

    control_unit brain (
        .clk(clk), .rst(rst), .start(start),
        .exec_done(effective_exec_done),
        .exec_busy(effective_exec_busy),
        .load_en(load_en),
        .exec_start(exec_start),
        .done(done)
    );

    register_8bit reg_A (.clk(clk), .rst(rst), .load_en(load_en), .data_in(A_raw), .data_out(A_internal));
    register_8bit reg_B (.clk(clk), .rst(rst), .load_en(load_en), .data_in(B_raw), .data_out(B_internal));

    assign sub_mode = (opcode == 2'b01);
    assign op_valid = (opcode == 2'b00) || (opcode == 2'b01);

    adder_substractor arithmetic_unit (
        .clk(clk),
        .rst(rst),
        .start(exec_start),
        .op1(A_internal),
        .op2(B_internal),
        .enable(op_valid),
        .sub_mode(sub_mode),
        .busy(exec_busy),
        .done(exec_done),
        .c_out(c_out),
        .overflow(overflow),
        .result(arithmetic_out)
    );

    assign effective_exec_busy = op_valid ? exec_busy : 1'b0;
    assign effective_exec_done = op_valid ? exec_done : 1'b1;

    assign selected_result = op_valid ? arithmetic_out : 8'b0;
    assign result = {6'b0, overflow, c_out, selected_result};

endmodule