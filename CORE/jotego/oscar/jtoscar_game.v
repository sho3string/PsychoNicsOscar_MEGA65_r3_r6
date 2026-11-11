
// Psycho-Nics Oscar - game-level ROM and video interface
// Other ROM address placeholders below are absolute BYTE offsets in the MRA image.
// CPU, graphics ROM decoding and sound logic are not connected yet.

module jtoscar_game (
    input  wire        rst,
    input  wire        clk,
    input  wire        cen_main,
    input  wire        cen_sub,
    input  wire        cen_snd,
    input  wire        cen_pixel,

    // Video outputs
    output wire        pxl_cen,
    output wire        HS,
    output wire        VS,
    output wire        LHBL,
    output wire        LVBL,
    output wire [3:0]  red,
    output wire [3:0]  green,
    output wire [3:0]  blue,

    // ROM interfaces
    output wire [19:0] main_rom_addr,
    input  wire [7:0]  main_rom_data,
    output wire [19:0] sub_rom_addr,
    input  wire [7:0]  sub_rom_data,
    output wire [19:0] snd_rom_addr,
    input  wire [7:0]  snd_rom_data,
    output wire [12:0] char_rom_addr,
    output wire        char_rom_cs,
    input  wire [23:0] char_rom_data,
    input  wire        char_rom_ok,
    // 1024x16-bit character RAM (temporary MAME snapshot in main.vhd)
    output wire [9:0]  cram_addr,
    input  wire [15:0] cram_data,
    output wire [19:0] obj_rom_addr,
    input  wire [7:0]  obj_rom_data,
    output wire [19:0] scr_rom_addr,
    input  wire [7:0]  scr_rom_data
);

    // ------------------------------------------------------------
    // Video timing and test pattern
    // ------------------------------------------------------------

    jtoscar_video u_video (
        .clk       ( clk     ),
        .rst       ( rst     ),
        .pxl_cen   ( pxl_cen ),
        .HS        ( HS      ),
        .VS        ( VS      ),
        .LHBL      ( LHBL    ),
        .LVBL      ( LVBL    ),
        // The tilemap addresses the ROM directly (not absolute MRA offsets).
        .char_addr ( char_rom_addr ),
        .char_cs   ( char_rom_cs   ),
        .char_data ( char_rom_data ),
        .char_ok   ( char_rom_ok   ),
        .cram_addr ( cram_addr ),
        .cram_data ( cram_data ),
        .red       ( red     ),
        .green     ( green   ),
        .blue      ( blue    )
    );

    // ------------------------------------------------------------
    // ROM address placeholders
    // ------------------------------------------------------------

    assign main_rom_addr = 20'h00000;
    assign sub_rom_addr  = 20'h18000;
    assign snd_rom_addr  = 20'h28000;
    assign obj_rom_addr  = 20'h38000;
    assign scr_rom_addr  = 20'h78000;

endmodule