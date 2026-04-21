module alu_top (
    input clk,
    input rst,
    input start,
    input [1:0] opcode,
    input [7:0] A_raw,
    input [7:0] B_raw,
    output wire [15:0] result,
    output carry_out,
    output overflow,
    output done
);

    wire load_en, exec_start;
    wire [7:0] A_internal, B_internal;

    wire sel_add = (opcode == 2'b00);
    wire sel_sub = (opcode == 2'b01);
    wire sel_mul = (opcode == 2'b10);
    wire sel_div = (opcode == 2'b11);
    wire sel_addsub = sel_add | sel_sub;

    wire addsub_busy, addsub_done, addsub_cout, addsub_overflow;
    wire [7:0] addsub_result;

    wire mul_busy, mul_done;
    wire [15:0] mul_result;

    wire div_ready, div_done;
    wire [7:0] div_quotient, div_remainder;

    wire busy_muldiv, effective_busy;
    mux2to1 #(.w(1)) mux_busy_muldiv (.in0(mul_busy),    .in1(~div_ready),  .sel(opcode[0]), .out(busy_muldiv));
    mux2to1 #(.w(1)) mux_busy        (.in0(addsub_busy), .in1(busy_muldiv), .sel(opcode[1]), .out(effective_busy));

    wire done_muldiv, effective_done;
    mux2to1 #(.w(1)) mux_done_muldiv (.in0(mul_done),    .in1(div_done),    .sel(opcode[0]), .out(done_muldiv));
    mux2to1 #(.w(1)) mux_done        (.in0(addsub_done), .in1(done_muldiv), .sel(opcode[1]), .out(effective_done));

    control_unit brain (
        .clk(clk), .rst(rst), .start(start),
        .exec_done(effective_done),
        .exec_busy(effective_busy),
        .load_en(load_en),
        .exec_start(exec_start),
        .done(done)
    );

    register_8bit reg_A (
        .clk(clk), .rst(rst),
        .load_en(load_en),
        .data_in(A_raw),
        .data_out(A_internal)
    );

    register_8bit reg_B (
        .clk(clk), .rst(rst),
        .load_en(load_en),
        .data_in(B_raw),
        .data_out(B_internal)
    );

    adder_substractor add_sub_unit (
        .clk(clk), .rst(rst),
        .start(exec_start),
        .op1(A_internal), .op2(B_internal),
        .enable(sel_addsub),
        .sub_mode(sel_sub),
        .busy(addsub_busy), .done(addsub_done),
        .c_out(addsub_cout), .overflow(addsub_overflow),
        .result(addsub_result)
    );

    booth_radix_4_multiplier mul_unit (
        .clk(clk), .rst(rst),
        .start(exec_start),
        .multiplicand(A_internal), .multiplier(B_internal),
        .enable(sel_mul),
        .busy(mul_busy), .done(mul_done),
        .product(mul_result)
    );

    radix2_div div_unit (
        .clk(clk), .reset(rst),
        .start(exec_start & sel_div),
        .dividend(A_internal), .divisor(B_internal),
        .quotient(div_quotient), .remainder(div_remainder),
        .ready(div_ready), .done(div_done)
    );

    assign carry_out = addsub_cout;
    assign overflow  = addsub_overflow;

    wire [15:0] result_muldiv;
    mux2to1 #(.w(16)) mux_result_muldiv (.in0(mul_result), .in1({div_remainder, div_quotient}), .sel(opcode[0]), .out(result_muldiv));
    mux2to1 #(.w(16)) mux_result        (.in0({8'b0, addsub_result}), .in1(result_muldiv),       .sel(opcode[1]), .out(result));

endmodule
