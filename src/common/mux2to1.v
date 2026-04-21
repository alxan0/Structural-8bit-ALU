module mux2to1 #(parameter w = 4) (
  input  [w-1:0] in0,
  input  [w-1:0] in1,
  input          sel,
  output [w-1:0] out
);

assign out = (sel == 1'b0) ? in0 : in1;

endmodule
