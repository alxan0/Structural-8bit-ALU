`timescale 1ns / 1ps

module radix2_div_tb;

    parameter WIDTH = 8;

    reg clk;
    reg reset;
    reg start;
    reg [WIDTH-1:0] dividend;
    reg [WIDTH-1:0] divisor;

    wire [WIDTH-1:0] quotient;
    wire [WIDTH-1:0] remainder;
    wire ready;
    wire done;

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

    always #5 clk = ~clk;

    task run_test(input [WIDTH-1:0] a, input [WIDTH-1:0] b);
        begin
            wait(ready);
            @(posedge clk);
            dividend = a;
            divisor  = b;
            start    = 1;
            @(posedge clk);
            start = 0;

            wait(done);
            #1;
            if ((quotient == (a / b)) && (remainder == (a % b))) begin
                $display("PASS: %0d / %0d = Q:%0d R:%0d", a, b, quotient, remainder);
            end else begin
                $display("FAIL: %0d / %0d = Q:%0d R:%0d (Expected Q:%0d R:%0d)",
                          a, b, quotient, remainder, (a / b), (a % b));
            end
            @(posedge clk);
        end
    endtask

    initial begin
        clk      = 0;
        reset    = 1;
        start    = 0;
        dividend = 0;
        divisor  = 0;

        #20;
        reset = 0;
        #10;

        run_test(8'd100, 8'd5);
        run_test(8'd25,  8'd4);
        run_test(8'd10,  8'd20);
        run_test(8'd50,  8'd3);
        run_test(8'd255, 8'd2);
        run_test(8'd0,   8'd5);
        run_test(8'd7,   8'd7);
        run_test(8'd1,   8'd1);
        run_test(8'd255, 8'd1);
        run_test(8'd100, 8'd7);
        run_test(8'd15,  8'd3);
        run_test(8'd1,   8'd2);
        run_test(8'd255, 8'd255);
        run_test(8'd128, 8'd9);

        #50;
        $display("--- All tests completed ---");
        $finish;
    end

endmodule
