module alu_top (
    input clk,
    input rst,
    input start,
    input [1:0] opcode,
    input [7:0] A_raw,
    input [7:0] B_raw,
    output reg [15:0] result,
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

    // Add/Sub
    wire addsub_busy, addsub_done, addsub_cout, addsub_overflow;
    wire [7:0] addsub_result;

    // Multiply
    wire mul_busy, mul_done;
    wire [15:0] mul_result;

    // Divide
    wire div_ready, div_done;
    wire [7:0] div_quotient, div_remainder;

    wire effective_busy = sel_addsub ? addsub_busy :
                          sel_mul    ? mul_busy    :
                          sel_div    ? ~div_ready  :
                                       1'b0;

    wire effective_done = sel_addsub ? addsub_done :
                          sel_mul    ? mul_done    :
                          sel_div    ? div_done    :
                                       1'b1;

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

    shift_add_multiplier mul_unit (
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

    always @(*) begin
        case (opcode)
            2'b00: result = {8'b0, addsub_result};          
            2'b01: result = {8'b0, addsub_result};          
            2'b10: result = mul_result;                     
            2'b11: result = {div_remainder, div_quotient};   // remainder:quotient
            default: result = 16'b0;
        endcase
    end

endmodule
