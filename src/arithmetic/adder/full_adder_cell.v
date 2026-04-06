module full_adder_cell(input x,
		       input y,
		       input cin,
		       output z,
		       output cout);

assign z=x^y^cin;
assign cout=(x&y) | (x&cin) | (y&cin);

endmodule
