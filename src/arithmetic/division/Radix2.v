// Code your design here
module radix2_div #(parameter WIDTH = 8) (
    input  wire clk,
    input  wire reset,
    input  wire start,
    input  wire [WIDTH-1:0] dividend,
    input  wire [WIDTH-1:0] divisor,
    output reg  [WIDTH-1:0] quotient,
    output reg  [WIDTH-1:0] remainder,
    output reg  ready,
    output reg  done
);

    // Internal registers
    reg [WIDTH-1:0] A, M, Q;
    reg [3:0] count;
    reg state;

    localparam IDLE = 1'b0;
    localparam CALC = 1'b1;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            state     <= IDLE;
            ready     <= 1;
            done      <= 0;
            quotient  <= 0;
            remainder <= 0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 0;
                    if (start) begin
                        A     <= 0;
                        M     <= divisor;
                        Q     <= dividend;
                        count <= WIDTH 	;
                        state <= CALC;
                        ready <= 0;
                    end
                end

                CALC: begin
                    if (count > 0) begin
                        // Shift A and Q left as a single unit
                        // We use a temporary wire to simulate the shift-then-sub/add
                        if (A[WIDTH-1] == 0) begin
                            // A is positive: Shift then Subtract
                            {A, Q} <= {A[WIDTH-2:0], Q, 1'b0}; 
                            // Note: We adjust the logic slightly for the non-restoring step
                            // In this hardware flow, we perform the math on the shifted A
                            if ({A[WIDTH-2:0], Q[WIDTH-1]} >= M) begin
                                A <= {A[WIDTH-2:0], Q[WIDTH-1]} - M;
                                Q <= {Q[WIDTH-2:0], 1'b1};
                            end else begin
                                A <= {A[WIDTH-2:0], Q[WIDTH-1]};
                                Q <= {Q[WIDTH-2:0], 1'b0};
                            end
                        end
                        count <= count - 1;
                    end else begin
                        // Final alignment
                        quotient  <= Q;
                        remainder <= A;
                        done      <= 1;
                        ready     <= 1;
                        state     <= IDLE;
                    end
                end
            endcase
        end
    end
endmodule