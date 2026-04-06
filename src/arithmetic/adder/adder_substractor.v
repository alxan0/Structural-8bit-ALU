module adder_substractor(
			  input clk,
			  input rst,
			  input start,
			  input[7:0] op1,
			  input[7:0] op2,
			  input enable,
			  input sub_mode,
			  output reg busy,
			  output reg done,
			  output reg c_out,
			  output reg overflow,
			  output reg[7:0]result);
wire [7:0] op2_xor;
wire [7:0] adder_result;
wire adder_c_out;
wire overflow_raw;
xor_wordgate#(.w(8)) gate (.in(op2), .bit_in(sub_mode), .out(op2_xor));


carry_select_adder add (.op1(op1), .op2(op2_xor), .c_in(sub_mode), .result(adder_result), .c_out(adder_c_out));

assign overflow_raw=(op1[7]==op2_xor[7]) && (adder_result[7] != op1[7]);

always @(posedge clk or posedge rst) begin
	if (rst) begin
		busy <= 1'b0;
		done <= 1'b0;
		c_out <= 1'b0;
		overflow <= 1'b0;
		result <= 8'b0;
	end else if (!enable) begin
		busy <= 1'b0;
		done <= 1'b0;
		c_out <= 1'b0;
		overflow <= 1'b0;
		result <= 8'b0;
	end else begin
		done <= 1'b0;
		if (start && !busy) begin
			busy <= 1'b1;
			result <= adder_result;
			c_out <= adder_c_out;
			overflow <= overflow_raw;
		end else if (busy) begin
			busy <= 1'b0;
			done <= 1'b1;
		end
	end
end

endmodule 