module Booth_PPG (
    input signed [7:0] M,       // Deicand (Multiplicand)
    input [2:0] triplet, // Grupul de 3 biti
    output reg signed [15:0] PP // Produsul partial extins la 16 biti
);
    wire signed [15:0] m_ext;
    wire signed [15:0] m2_ext;

    // Extindem semnul la 16 biti inainte de operatii pentru a evita overflow pe 8 biti
    assign m_ext = {{8{M[7]}}, M};
    assign m2_ext = m_ext <<< 1;

    always @(*) begin
        case (triplet)
            3'b000, 3'b111: PP = 16'h0000;
            3'b001, 3'b010: PP = m_ext;    // +M
            3'b011:         PP = m2_ext;   // +2M
            3'b100:         PP = -m2_ext;  // -2M
            3'b101, 3'b110: PP = -m_ext;   // -M
            default:        PP = 16'h0000;
        endcase
    end
endmodule