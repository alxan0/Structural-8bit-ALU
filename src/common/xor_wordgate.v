module xor_wordgate#(parameter w=8)
(input [w-1:0] in,
input bit_in,
output [w-1:0] out
);

assign out=in ^ {w{bit_in}};

endmodule 


