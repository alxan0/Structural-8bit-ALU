module control_unit (
    input clk,
    input rst,
    input start,
    output reg load_en,
    output reg done,
    output reg [1:0] state_out
);
    parameter IDLE = 2'b00, 
              LOAD = 2'b01, 
              EXEC = 2'b10, 
              DONE = 2'b11;
    reg [1:0] state, next_state;

    always @(posedge clk or posedge rst) begin
        if (rst) state <= IDLE;
        else state <= next_state;
    end

    always @(*) begin
        case (state)
            IDLE: next_state = (start) ? LOAD : IDLE;
            LOAD: next_state = EXEC;
            EXEC: next_state = DONE; // For now, EXEC is only 1 cycle
            DONE: next_state = (start) ? DONE : IDLE;
            default: next_state = IDLE;
        endcase
    end

    always @(*) begin
        load_en = (state == LOAD);
        done = (state == DONE);
        state_out = state;
    end
endmodule