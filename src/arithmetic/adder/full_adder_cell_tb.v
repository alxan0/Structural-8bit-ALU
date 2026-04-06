module full_adder_cell_tb;
  reg x;
  reg y;
  reg cin;
  wire z;
  wire cout;
  
  full_adder_cell uut (
    .x(x),
    .y(y),
    .cin(cin),
    .z(z),
    .cout(cout)
  );
  
  integer i;
  initial begin
    {x, y, cin} = 3'b000;
    $display("Time\tx\ty\tc_in\tz\tc_out");
    $monitor("%0t\t%b\t%b\t%b\t%b\t%b", $time, x, y, cin, z, cout);
    for(i = 1 ; i < 8 ; i = i + 1) begin
      #10 {x, y, cin} = i;
    end
  end
  
endmodule
