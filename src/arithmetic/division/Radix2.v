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

    reg [WIDTH-1:0] A, M, Q;
    reg [3:0] count;
    reg state;

    localparam IDLE = 1'b0;
    localparam CALC = 1'b1;

    wire [WIDTH-1:0] shifted_A = {A[WIDTH-2:0], Q[WIDTH-1]};

    wire [WIDTH-1:0] M_inv;
    xor_wordgate #(.w(WIDTH)) neg_m (.in(M), .bit_in(1'b1), .out(M_inv));

    wire [WIDTH-1:0] sub_result;
    wire sub_cout;
    carry_select_adder sub_adder (.op1(shifted_A), .op2(M_inv), .c_in(1'b1), .result(sub_result), .c_out(sub_cout));

    wire [WIDTH-1:0] restore_result;
    carry_select_adder restore_adder (.op1(sub_result), .op2(M), .c_in(1'b0), .result(restore_result), .c_out());

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
                        count <= WIDTH;
                        state <= CALC;
                        ready <= 0;
                    end
                end

                CALC: begin
                    if (count > 0) begin
                        if (sub_cout) begin
                            A <= sub_result;
                            Q <= {Q[WIDTH-2:0], 1'b1};
                        end else begin
                            A <= restore_result;
                            Q <= {Q[WIDTH-2:0], 1'b0};
                        end
                        count <= count - 1;
                    end else begin
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
