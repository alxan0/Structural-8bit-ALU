module ripple_carry_adder #(parameter w=4)(op1, op2, result, c_out, c_in);
input [w-1:0] op1;
wire signed [w-1: 0] op1;
input [w-1:0] op2;
wire signed [w-1:0] op2;
input c_in;
wire c_in;
output [w-1:0] result;
wire signed [w-1:0] result;
output c_out;
wire c_out;

wire [w-2:0] internal_carry;

genvar i;
generate
	for(i=0; i<w; i=i+1) begin:full_adder_cells
		if(i==0) begin
			full_adder_cell first_cell(.x(op1[0]), .y(op2[0]), .cin(c_in), .z(result[0]), .cout(internal_carry[0]));
		end
		else if(i==w-1) begin
			full_adder_cell last_cell(.x(op1[w-1]), .y(op2[w-1]), .cin(internal_carry[w-2]), .z(result[w-1]), .cout(c_out));
		end
		else begin
		full_adder_cell  internal_cell(.x(op1[i]), .y(op2[i]), .cin(internal_carry[i-1]), .z(result[i]), .cout(internal_carry[i]));
		end
end
endgenerate
endmodule

