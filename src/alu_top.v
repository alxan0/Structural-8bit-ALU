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
    wire [7:0] A_internal, B_internal;

    control_unit brain (
        .clk(clk), .rst(rst), .start(start),
        .load_en(load_en), .done(done)
    );

    register_8bit reg_A (.clk(clk), .rst(rst), .load_en(load_en), .data_in(A_raw), .data_out(A_internal));
    register_8bit reg_B (.clk(clk), .rst(rst), .load_en(load_en), .data_in(B_raw), .data_out(B_internal));

    assign result = {A_internal, B_internal};

endmodule