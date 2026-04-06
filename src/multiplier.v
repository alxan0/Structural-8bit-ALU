module multiplier (
    input clk,
    input reset,
    input start,
    input signed [7:0] A, // Multiplicand
    input signed [7:0] B, // Multiplicator
    output reg signed [15:0] Product,
    output reg ready
);

    reg [2:0] state;
    reg signed [15:0] accumulator;
    reg signed [7:0] M, Q;
    reg [2:0] count;
    
    wire signed [15:0] current_pp;
    wire signed [15:0] shifted_pp;
    wire signed [15:0] sum_out;
    
    // 1. Instantiem PPG-ul pentru a determina ce adunam
    // Tripletul este format din biții corespunzători din Q
    // La prima iteratie (count=0), tripletul e {Q[1], Q[0], 1'b0}
    wire [2:0] current_triplet;
    assign current_triplet = (count == 0) ? {Q[1], Q[0], 1'b0} : 
                             (count == 1) ? {Q[3], Q[2], Q[1]} :
                             (count == 2) ? {Q[5], Q[4], Q[3]} :
                                            {Q[7], Q[6], Q[5]};

    Booth_PPG ppg_inst (
        .M(M),
        .triplet(current_triplet),
        .PP(current_pp)
    );

    // 2. Shiftarea produsului partial in functie de iteratie (0, 2, 4, 6 pozitii)
    assign shifted_pp = current_pp << (count * 2);

    // 3. AICI INSEREZI ADUNORUL COLEGULUI
    // Inlocuieste acest "assign" cu instantierea modulului lui: 
    // Exemplu: MyAdder16Bit adder_inst (.A(accumulator), .B(shifted_pp), .Sum(sum_out));
    assign sum_out = accumulator + shifted_pp;

    // 4. Logica de Control (FSM)
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            state <= 0;
            ready <= 0;
            Product <= 0;
            accumulator <= 0;
            count <= 0;
        end else begin
            case (state)
                0: begin // Idle
                    ready <= 0;
                    if (start) begin
                        M <= A;
                        Q <= B;
                        accumulator <= 0;
                        count <= 0;
                        state <= 1;
                    end
                end
                1: begin // Calcul (4 pasi pentru 8 biti)
                    ready <= 0;
                    accumulator <= sum_out;
                    if (count == 3) begin
                        state <= 2;
                    end else begin
                        count <= count + 1;
                    end
                end
                2: begin // Finish
                    Product <= accumulator;
                    ready <= 1;
                    state <= 0;
                end
                default: begin
                    state <= 0;
                    ready <= 0;
                end
            endcase
        end
    end
endmodule



module tb_multiplier();
    reg clk, reset, start;
    reg signed [7:0] A, B;
    wire signed [15:0] Product;
    wire ready;

    multiplier uut (
        .clk(clk),
        .reset(reset),
        .start(start),
        .A(A),
        .B(B),
        .Product(Product),
        .ready(ready)
    );

    always #5 clk = ~clk;

    task automatic run_case;
        input signed [7:0] ta;
        input signed [7:0] tb;
        reg signed [15:0] expected;
    begin
        expected = ta * tb;

        @(negedge clk);
        A = ta;
        B = tb;
        start = 1'b1;

        @(negedge clk);
        start = 1'b0;

        // Asteptam frontul pozitiv, nu doar nivelul, ca sa evitam false-positive
        @(posedge ready);

        if (Product !== expected) begin
            $display("ERROR: %0d * %0d = %0d (0x%h), expected %0d (0x%h)",
                     ta, tb, Product, Product, expected, expected);
        end else begin
            $display("OK: %0d * %0d = %0d", ta, tb, Product);
        end
    end
    endtask

    initial begin
        clk = 0; reset = 1; start = 0;
        A = 0; B = 0;
        #15 reset = 0;

        run_case(8'sd12, 8'sd5);
        run_case(-8'sd3, 8'sd4);
        run_case(-8'sd8, 8'sd5);
        run_case(8'sd12, -8'sd4);
        run_case(-8'sd9, -8'sd6);
        run_case(8'sd127, 8'sd127);
        run_case(-8'sd128, 8'sd1);
        run_case(-8'sd128, -8'sd1);
        
        #50 $finish;
    end
endmodule