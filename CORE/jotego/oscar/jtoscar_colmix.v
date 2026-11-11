// Psycho-Nics Oscar foreground-only colour mixer.
// MAME gfx_oscar: character palette base 256, 8 pens per colour group.
// DECO RM-C3 palette RAM: xxxxBBBBGGGGRRRR, one 16-bit entry per colour.
// Resistor weights per 4-bit channel: 0x0e, 0x1f, 0x43, 0x8f.
// Character pen 0 is transparent; without background/sprites it shows black.
module jtoscar_colmix (
    input  wire        clk,
    input  wire        LHBL,
    input  wire        LVBL,
    input  wire [5:0]  char_pxl,

    output wire [8:0]  palette_addr,
    input  wire [15:0] palette_data,

    output wire [7:0]  red,
    output wire [7:0]  green,
    output wire [7:0]  blue
);

    // Foreground palette entries are 256..319 (only groups 0..3
    // currently selected by the Oscar character RAM attribute bits).
    // Port 1 of palette RAM has a one-clock synchronous read latency.
    assign palette_addr = {3'b100, char_pxl};

    // Delay visibility and transparency by the same clock as the RAM read.
    reg        visible_d = 1'b0;
    reg [2:0]  pen_d     = 3'b000;

    always @(posedge clk) begin
        visible_d <= LHBL && LVBL;
        pen_d     <= char_pxl[2:0];
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

    wire foreground_visible = visible_d && (pen_d != 3'd0);

    assign red   = foreground_visible ? deco_rmc3_channel(palette_data[3:0])  : 8'd0;
    assign green = foreground_visible ? deco_rmc3_channel(palette_data[7:4])  : 8'd0;
    assign blue  = foreground_visible ? deco_rmc3_channel(palette_data[11:8]) : 8'd0;

endmodule
