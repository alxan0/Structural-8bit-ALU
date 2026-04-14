module booth_radix_4_multiplier (
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

    // Radix-4 Booth (signed, 8-bit x 8-bit -> 16-bit):
    //   Y = {multiplier, 1'b0}, X = multiplicand, ACC = 0
    //   Repeat 4 times (2 multiplier bits/step):
    //     decode Y[2:0] in {-2,-1,0,+1,+2} * X
    //     ACC = ACC +/- (X or 2X)
    //     Y >>>= 2 (arithmetic), X <<= 2

    reg signed [15:0] acc;
    reg signed [15:0] x_shift;
    reg signed [8:0]  y_ext;
    reg [2:0]  count;

    localparam IDLE = 2'b00,
               CALC = 2'b01,
               FINISH = 2'b10;

    reg [1:0] state;

    reg signed [15:0] booth_operand;
    reg booth_sub;

    wire signed [15:0] x2 = x_shift <<< 1;

    wire [15:0] booth_operand_xor;
    wire [7:0] add_lo_result;
    wire [7:0] add_hi_result;
    wire add_lo_cout;
    wire add_hi_cout;
    wire [15:0] acc_next_bits = {add_hi_result, add_lo_result};

    xor_wordgate #(.w(8)) inv_lo (
        .in(booth_operand[7:0]),
        .bit_in(booth_sub),
        .out(booth_operand_xor[7:0])
    );

    xor_wordgate #(.w(8)) inv_hi (
        .in(booth_operand[15:8]),
        .bit_in(booth_sub),
        .out(booth_operand_xor[15:8])
    );

    carry_select_adder add_lo (
        .op1(acc[7:0]),
        .op2(booth_operand_xor[7:0]),
        .c_in(booth_sub),
        .result(add_lo_result),
        .c_out(add_lo_cout)
    );

    carry_select_adder add_hi (
        .op1(acc[15:8]),
        .op2(booth_operand_xor[15:8]),
        .c_in(add_lo_cout),
        .result(add_hi_result),
        .c_out(add_hi_cout)
    );

    always @(*) begin
        booth_operand = 16'b0;
        booth_sub = 1'b0;

        case (y_ext[2:0])
            3'b001,
            3'b010: begin
                booth_operand = x_shift;
                booth_sub = 1'b0;
            end
            3'b011: begin
                booth_operand = x2;
                booth_sub = 1'b0;
            end
            3'b100: begin
                booth_operand = x2;
                booth_sub = 1'b1;
            end
            3'b101,
            3'b110: begin
                booth_operand = x_shift;
                booth_sub = 1'b1;
            end
            default: begin
                booth_operand = 16'b0;
                booth_sub = 1'b0;
            end
        endcase
    end

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state   <= IDLE;
            busy    <= 0;
            done    <= 0;
            product <= 0;
            acc     <= 0;
            x_shift <= 0;
            y_ext   <= 0;
            count   <= 0;
        end else if (!enable) begin
            state   <= IDLE;
            busy    <= 0;
            done    <= 0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 0;
                    if (start) begin
                        acc     <= 16'b0;
                        x_shift <= $signed({{8{multiplicand[7]}}, multiplicand});
                        y_ext   <= $signed({multiplier, 1'b0});
                        count   <= 3'd4;
                        state   <= CALC;
                        busy    <= 1;
                    end
                end

                CALC: begin
                    if (count > 0) begin
                        acc     <= $signed(acc_next_bits);
                        x_shift <= x_shift <<< 2;
                        y_ext   <= y_ext >>> 2;
                        count <= count - 1;
                    end else begin
                        product <= acc;
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
