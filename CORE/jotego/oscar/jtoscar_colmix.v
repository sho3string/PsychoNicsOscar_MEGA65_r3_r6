// Psycho-Nics Oscar foreground / MXC06 sprite / BAC06 background colour mixer.
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
    input  wire [7:0]  obj_pxl,

    output wire [8:0]  palette_addr,
    input  wire [15:0] palette_data,

    output wire [7:0]  red,
    output wire [7:0]  green,
    output wire [7:0]  blue
);

    // MAME Oscar priority: foreground > BAC06 high-priority pens >
    // MXC06 sprites > BAC06 normal background.
    // Only palettes 8-15 with pens 8-15 cover sprites.
    wire char_opaque = char_pxl[2:0] != 3'd0;
    wire obj_opaque  = obj_pxl[3:0]  != 4'd0;
    wire bg_priority = bg_pxl[7] && bg_pxl[3];

    assign palette_addr = char_opaque ? {3'b100, char_pxl} :
                          bg_priority || !obj_opaque ? {2'b11, bg_pxl[6:0]} :
                                                       {1'b0, obj_pxl};

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
