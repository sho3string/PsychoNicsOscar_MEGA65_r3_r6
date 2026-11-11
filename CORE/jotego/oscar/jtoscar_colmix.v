// Psycho-Nics Oscar foreground-over-BAC06 background colour mixer.
// MAME gfx_oscar: character palette base 256, 8 pens per colour group.
// DECO RM-C3 palette RAM: xxxxBBBBGGGGRRRR, one 16-bit entry per colour.
// Resistor weights per 4-bit channel: 0x0e, 0x1f, 0x43, 0x8f.
// Character pen 0 is transparent, revealing the BAC06 background.
module jtoscar_colmix (
    input  wire        clk,
    input  wire        LHBL,
    input  wire        LVBL,
    input  wire [5:0]  char_pxl,
    input  wire [7:0]  bg_pxl,

    output wire [8:0]  palette_addr,
    input  wire [15:0] palette_data,

    output wire [7:0]  red,
    output wire [7:0]  green,
    output wire [7:0]  blue
);

    // Palette: chars 256..319, background 384..511.
    // Character pen 0 reveals the background. The BAC06 output contains
    // four palette-select bits and four graphic pen bits, but Oscar only
    // decodes eight background palettes (3 group bits).
    wire char_opaque = char_pxl[2:0] != 3'd0;
    assign palette_addr = char_opaque ? {3'b100, char_pxl} :
                                        {2'b11, bg_pxl[6:0]};

    // Palette RAM's video read is synchronous (one 48 MHz clock).
    reg visible_d = 1'b0;

    always @(posedge clk) begin
        visible_d <= LHBL && LVBL;
    end

    function [7:0] deco_rmc3_channel;
        input [3:0] nibble;
        begin
            deco_rmc3_channel =
                (nibble[0] ? 8'h0e : 8'h00) +
                (nibble[1] ? 8'h1f : 8'h00) +
                (nibble[2] ? 8'h43 : 8'h00) +
                (nibble[3] ? 8'h8f : 8'h00);
        end
    endfunction

    assign red   = visible_d ? deco_rmc3_channel(palette_data[3:0])  : 8'd0;
    assign green = visible_d ? deco_rmc3_channel(palette_data[7:4])  : 8'd0;
    assign blue  = visible_d ? deco_rmc3_channel(palette_data[11:8]) : 8'd0;

endmodule
