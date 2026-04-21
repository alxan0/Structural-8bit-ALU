module carry_select_adder(
	input [7:0] op1,
	input [7:0] op2,
	input c_in,
	output [7:0] result,
	output c_out
);
wire c_mid;

ripple_carry_adder #(.w(4)) least_significand_part(
.op1(op1[3:0]),
.op2(op2[3:0]),
.c_in(c_in),
.result(result[3:0]),
.c_out(c_mid));


adder_level most_significand_part(
.op1(op1[7:4]),
.op2(op2[7:4]),
.c_in(c_mid),
.result(result[7:4]),
.c_out(c_out));


endmodule
