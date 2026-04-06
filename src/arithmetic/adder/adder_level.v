module adder_level(op1, op2, c_in, result, c_out);
input [3:0] op1;
wire signed [3:0] op1;
input [3:0] op2;
wire signed [3:0] op2;
input c_in;
wire c_in;
output [3:0]result;
wire signed[3:0] result;
output c_out;
wire c_out;

wire [3:0]carry_0_result;
wire [3:0]carry_1_result;
wire c_out_carry_0;
wire c_out_carry_1;

ripple_carry_adder ripple_carry_adder_0(.op1(op1), .op2(op2), .c_in(1'b0), .result(carry_0_result),
					.c_out(c_out_carry_0));
ripple_carry_adder ripple_carry_adder_1(.op1(op1), .op2(op2), .c_in(1'b1), .result(carry_1_result),
					.c_out(c_out_carry_1));


mux2to1 result_selector(.in0(carry_0_result),
			.in1(carry_1_result),
			.sel(c_in),
			.out(result));

mux2to1 #(.w(1)) carry_selector(.in0(c_out_carry_0),
				.in1(c_out_carry_1),
				.sel(c_in),
				.out(c_out));

endmodule

