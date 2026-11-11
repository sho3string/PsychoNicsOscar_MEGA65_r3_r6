// Temporary Psycho-Nics Oscar character-only colour mixer.
// The RAM-test snapshot uses attribute 0 for every tile.
// Treat graphics pen 0 as black/transparent and all others as white.
// This is not the final palette or layer-priority implementation.
module jtoscar_colmix (
    input  wire       LHBL,
    input  wire       LVBL,
    input  wire [5:0] char_pxl,
    output wire [3:0] red,
    output wire [3:0] green,
    output wire [3:0] blue
);

    wire white = LHBL && LVBL && (char_pxl[2:0] != 3'b000);

    assign red   = {4{white}};
    assign green = {4{white}};
    assign blue  = {4{white}};

endmodule
