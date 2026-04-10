// Code your testbench here
// or browse Examples
`timescale 1ns / 1ps

module radix2_div_tb;

    // Parameters
    parameter WIDTH = 8;

    // Inputs
    reg clk;
    reg reset;
    reg start;
    reg [WIDTH-1:0] dividend;
    reg [WIDTH-1:0] divisor;

    // Outputs
    wire [WIDTH-1:0] quotient;
    wire [WIDTH-1:0] remainder;
    wire ready;
    wire done;

    // Instantiate the Unit Under Test (UUT)
    radix2_div #(WIDTH) uut (
        .clk(clk), 
        .reset(reset), 
        .start(start), 
        .dividend(dividend), 
        .divisor(divisor), 
        .quotient(quotient), 
        .remainder(remainder), 
        .ready(ready), 
        .done(done)
    );

    // Clock generation
    always #5 clk = ~clk;

    // Test Procedure
    initial begin
        // Initialize Inputs
        clk = 0;
        reset = 1;
        start = 0;
        dividend = 0;
        divisor = 0;

        // Release Reset
        #20;
        reset = 0;
        #10;

        // Test Case 1: Simple division (100 / 5)
        run_test(8'd100, 8'd5);

        // Test Case 2: Division with remainder (25 / 4)
        run_test(8'd25, 8'd4);

        // Test Case 3: Dividend smaller than divisor (10 / 20)
        run_test(8'd10, 8'd20);

        // Test Case 4: Division by 1 (50 / 1)
      run_test(8'd50, 8'd3);

        // Test Case 5: Max values (255 / 2)
        run_test(8'd255, 8'd2);

        #50;
        $display("--- All tests completed ---");
        $finish;
    end

    // Task to handle the handshake and reporting
    task run_test(input [WIDTH-1:0] a, input [WIDTH-1:0] b);
        begin
            wait(ready);
            @(posedge clk);
            dividend = a;
            divisor = b;
            start = 1;
            @(posedge clk);
            start = 0;
            
            wait(done);
            #1; // Small delay to let outputs settle
            if ((quotient == (a / b)) && (remainder == (a % b))) begin
                $display("PASS: %d / %d = Q:%d R:%d", a, b, quotient, remainder);
            end else begin
                $display("FAIL: %d / %d = Q:%d R:%d (Expected Q:%d R:%d)", 
                          a, b, quotient, remainder, (a / b), (a % b));
            end
            @(posedge clk);
        end
    endtask

endmodule