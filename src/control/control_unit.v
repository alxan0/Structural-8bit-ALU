module control_unit (
    input clk,
    input rst,
    input start,
    input exec_done,
    input exec_busy,
    output reg load_en,
    output reg exec_start,
    output reg done
);
    localparam IDLE = 2'b00,
               LOAD = 2'b01,
               EXEC = 2'b10,
               DONE = 2'b11;

    reg [1:0] state, next_state;

    always @(posedge clk or posedge rst) begin
        if (rst) state <= IDLE;
        else     state <= next_state;
    end

    always @(*) begin
        case (state)
            IDLE:    next_state = start    ? LOAD : IDLE;
            LOAD:    next_state = EXEC;
            EXEC:    next_state = exec_done ? DONE : EXEC;
            DONE:    next_state = start    ? DONE : IDLE;
            default: next_state = IDLE;
        endcase
    end

    always @(*) begin
        load_en    = (state == LOAD);
        exec_start = (state == EXEC) && !exec_busy && !exec_done;
        done       = (state == DONE);
    end
endmodule
