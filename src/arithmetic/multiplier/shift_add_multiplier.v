module shift_add_multiplier (
    input clk,
    input rst,
    input start,
    input [7:0] multiplicand,
    input [7:0] multiplier,
    input enable,
    output reg busy,
    output reg done,
    output reg [15:0] product
);

    // Shift-and-add algorithm:
    //   A = 0, Q = multiplier, M = multiplicand
    //   Repeat 8 times:
    //     if Q[0]: A = A + M
    //     shift {carry, A, Q} right by 1
    //   Result: {A, Q} = 16-bit product

    reg [7:0] A;    // upper accumulator
    reg [7:0] Q;    // lower half (shifts right, multiplier bits fall out)
    reg [7:0] M;    // multiplicand (held constant)
    reg [3:0] count;
    reg carry;

    wire [7:0] sum;
    wire sum_cout;

    // Reuse the structural carry-select adder for the add step
    carry_select_adder adder (
        .op1(A),
        .op2(M),
        .c_in(1'b0),
        .result(sum),
        .c_out(sum_cout)
    );

    localparam IDLE = 2'b00,
               CALC = 2'b01,
               FINISH = 2'b10;

    reg [1:0] state;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state   <= IDLE;
            busy    <= 0;
            done    <= 0;
            product <= 0;
            A       <= 0;
            Q       <= 0;
            M       <= 0;
            count   <= 0;
            carry   <= 0;
        end else if (!enable) begin
            state   <= IDLE;
            busy    <= 0;
            done    <= 0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 0;
                    if (start) begin
                        A     <= 0;
                        Q     <= multiplier;
                        M     <= multiplicand;
                        count <= 8;
                        carry <= 0;
                        state <= CALC;
                        busy  <= 1;
                    end
                end

                CALC: begin
                    if (count > 0) begin
                        if (Q[0]) begin
                            // Add multiplicand, then shift right
                            {A, Q} <= {sum_cout, sum, Q[7:1]};
                        end else begin
                            // Just shift right
                            {A, Q} <= {1'b0, A, Q[7:1]};
                        end
                        count <= count - 1;
                    end else begin
                        product <= {A, Q};
                        state   <= FINISH;
                    end
                end

                FINISH: begin
                    busy  <= 0;
                    done  <= 1;
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule
