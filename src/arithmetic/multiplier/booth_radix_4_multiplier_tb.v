`timescale 1ns / 1ps

module booth_radix_4_multiplier_tb;
    reg clk;
    reg rst;
    reg start;
    reg enable;
    reg signed [7:0] multiplicand;
    reg signed [7:0] multiplier;

    wire busy;
    wire done;
    wire [15:0] product;
    wire signed [15:0] product_signed = product;

    booth_radix_4_multiplier dut (
        .clk(clk),
        .rst(rst),
        .start(start),
        .multiplicand(multiplicand),
        .multiplier(multiplier),
        .enable(enable),
        .busy(busy),
        .done(done),
        .product(product)
    );

    always #5 clk = ~clk;

    task run_case;
        input signed [7:0] a;
        input signed [7:0] b;
        input [8*32-1:0] label;
        reg signed [15:0] expected;
        integer timeout_cycles;
        begin
            expected = a * b;

            @(negedge clk);
            multiplicand = a;
            multiplier = b;
            start = 1'b1;

            @(negedge clk);
            start = 1'b0;

            timeout_cycles = 0;
            while (done !== 1'b1 && timeout_cycles < 40) begin
                @(negedge clk);
                timeout_cycles = timeout_cycles + 1;
            end

            if (done !== 1'b1) begin
                $display("FAIL [%0s]: timeout waiting done (A=%0d B=%0d)", label, a, b);
                $fatal(1);
            end

            #1;
            if (product !== expected) begin
                $display("FAIL [%0s]: A=%0d B=%0d expected=%0d got=%0d (exp=0x%04h got=0x%04h)",
                         label, a, b, expected, product_signed, expected, product);
                $fatal(1);
            end else begin
                $display("PASS [%0s]: A=%0d B=%0d product=%0d (0x%04h) cycles=%0d",
                         label, a, b, product_signed, product, timeout_cycles);
            end

            @(negedge clk);
        end
    endtask

    integer i;
    reg signed [7:0] ra;
    reg signed [7:0] rb;

    initial begin
        clk = 1'b0;
        rst = 1'b1;
        start = 1'b0;
        enable = 1'b1;
        multiplicand = 8'sd0;
        multiplier = 8'sd0;

        #20;
        rst = 1'b0;

        run_case(8'sd0,    8'sd0,    "0*0");
        run_case(8'sd7,    8'sd6,    "7*6");
        run_case(8'sd12,   8'sd12,   "12*12");
        run_case(-8'sd1,   8'sd127,  "-1*127");
        run_case(-8'sd2,  -8'sd3,    "-2*-3");
        run_case(-8'sd128, 8'sd127,  "-128*127");
        run_case(8'sd127, -8'sd128,  "127*-128");
        run_case(-8'sd128,-8'sd128,  "-128*-128");
        run_case(8'sd85,  -8'sd13,   "85*-13");
        run_case(-8'sd100, 8'sd37,   "-100*37");

        for (i = 0; i < 30; i = i + 1) begin
            ra = $random;
            rb = $random;
            run_case(ra, rb, "random");
        end

        $display("ALL BOOTH RADIX-4 MULTIPLIER TESTS PASSED");
        $finish;
    end

    initial begin
        $dumpfile("booth_radix_4_multiplier_tb.vcd");
        $dumpvars(0, booth_radix_4_multiplier_tb);
    end

endmodule
